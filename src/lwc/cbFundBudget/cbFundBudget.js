/**
Copyright (c) 10 2022, CloudBudget, Inc.
All rights reserved.
Redistribution and use in source and binary forms, with or without modification,
are permitted provided that the following conditions are met:
 * Redistributions of source code must retain the above copyright notice,
this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice,
this list of conditions and the following disclaimer in the documentation
and/or other materials provided with the distribution.
 * Neither the name of the CloudBudget, Inc. nor the names of its contributors
may be used to endorse or promote products derived from this software
without specific prior written permission.
THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
OF THE POSSIBILITY OF SUCH DAMAGE.

 */
import {api, LightningElement, track} from 'lwc';
import getDataForMappingServer from '@salesforce/apex/CBActualLoaderPageController.getDataForMappingServer';
import saveCBInvoicesServer from '@salesforce/apex/CBActualLoaderPageController.saveCBInvoicesServer';
import {_applyDecStyle, _getCopy, _message, _parseServerError, _setCell} from "c/cbUtils";
import {loadScript} from 'lightning/platformResourceLoader';
import exceljs from '@salesforce/resourceUrl/cb5__exceljs';

export default class CBActualLoader extends LightningElement {

	@api recordId;
	@track data;
	@track logs = [];
	@track showSpinner = false;
	@track showUploadButton = true;
	@track cbTransactions = []; // all transactions
	@track displayedTransactions = []; // transactions on the display
	@track cbTransactionPortion = [];
	@track report = [];
	@track dataMapping = {};
	@track totalLine = {};
	@track warningList = [];
	@track savingDisabled = true;
	@track invoiceWrappers = [];
	filesUploaded = [];
	file;
	fileLines = [];
	fileReader;
	content;
	accounts = [];

	connectedCallback() {
		_applyDecStyle();
		this.getDataForMapping();
	};

	getDataForMapping = () => {
		getDataForMappingServer()
			.then(mapping => this.dataMapping = mapping)
			.catch(e => _parseServerError('Get Data Mapping Error : ', e))
	};

	/**
	 * Method gets a file
	 */
	handleFilesUploading(event) {
		this.report = [];
		this.cbTransactions = [];
		this.fileLines = [];
		if (event.target.files.length > 0) {
			this.showSpinner = true;
			this.filesUploaded = event.target.files;
			this.report.push('File name : ' + event.target.files[0].name);
			this.manageFileData();
		}
	}

	manageFileData() {
		this.file = this.filesUploaded[0];
		this.showSpinner = true;
		this.fileReader = new FileReader();
		this.fileReader.onloadend = (async () => {
			this.manageInvoices(this.fileReader.result);
			//await this.generatePreviewTable(this.fileReader.result);
		});
		this.fileReader.readAsText(this.file);
	}

	manageInvoices = (rawData) => {
		try {
			const invoiceWrappers = [];
			this.warningList = [];
			this.invoiceWrappers = [];
			const {accounts, periods, budgetLines, vendors} = this.dataMapping;
			let lastWrapperName;

			rawData.split(/\r?\n/).forEach((line, idx) => {
				try {
					if (idx === 0 || !line || line.length < 10) {
						return;
					}

					const lineArray = this.splitByComa(line);
					if (!lineArray || lineArray.length < 5) return;
					//Get line values with spec     //Row Index
					const [
						, 							//0
						invoiceName, 				//1
						invoiceAccountName, 		//2
						invoiceDate,				//3
						invoicePeriodName,			//4
						invoiceBudgetLineName,		//5
						invoiceVendorName,			//6
						invoiceLineName,			//7
						invoiceLineAmountStr,		//8
					] = lineArray.map(item => item?.trim());
					// Convert names to Ids
					const invoiceAccountId = accounts[invoiceAccountName];
					this.validateInvoiceLine(invoiceAccountName, invoiceAccountId, 'Account', idx);

					const invoiceBudgetLineId = budgetLines[invoiceBudgetLineName];
					this.validateInvoiceLine(invoiceBudgetLineName, invoiceBudgetLineId, 'Budget Line', idx);

					const invoiceVendorId = vendors[invoiceVendorName];
					this.validateInvoiceLine(invoiceVendorName, invoiceVendorId, 'Vendor', idx);

					const invoicePeriodId = periods[invoicePeriodName];
					this.validateInvoiceLine(invoicePeriodName, invoicePeriodId, 'Period', idx);

					this.validateInvoiceLine(invoiceName, 'stump', 'Name', idx);

					let lineWrapper;
					const isSameInvoice = lastWrapperName === invoiceName;

					if (isSameInvoice) {
						lineWrapper = invoiceWrappers[invoiceWrappers.length - 1];
					} else {
						lineWrapper = {
							invoice: {
								Name: invoiceName,
								cb5__CBAccount__c: invoiceAccountId,
								CB_Budget_Line__c: invoiceBudgetLineId,
								cb5__CBPeriod__c: invoicePeriodId,
								cb5__CBVariable2__c: invoiceVendorId,
								cb5__InvoiceDate__c: invoiceDate.replace(/\//g, '-'),
							},
							invoiceLines: [],
						};
						invoiceWrappers.push(lineWrapper);
					}
					lastWrapperName = invoiceName;
					lineWrapper.invoiceLines.push({
						Name: invoiceLineName ? invoiceLineName : '-',
						cb5__Amount__c: invoiceLineAmountStr ? parseFloat(invoiceLineAmountStr) : 0
					});
				} catch (e) {
					console.error('Parse inside Error : ' + e);
				}
			});
			this.invoiceWrappers = invoiceWrappers;
			if (this.warningList.length > 0) {
				this.warningList = _getCopy(this.warningList);
				this.showSpinner = false;
				return;
			}
			this.saveCBInvoices();
		} catch (e) {
			console.error(e);
		}
	};

	/**
	 * Method inserts a list of invoices and its lines
	 */
	saveCBInvoices = () => {
		this.showSpinner = true;
		saveCBInvoicesServer({invoiceWrappers: this.invoiceWrappers})
			.then(() => {
				_message('success', 'Saved');
				this.showSpinner = false;
				this.cancelCBInvoices();
			})
			.catch(e => _parseServerError('Saving Error : ', e))
			.finally(() => this.showSpinner = false);
	};

	validateInvoiceLine = (name, id, title, idx) => {
		if (!name) {
			this.warningList.push(`Line #${idx}. Invoice Line does not have ${title}`);
		} else if (!id) {
			this.warningList.push(`Line #${idx}. There is no ${title} "${name}" in the system`);
		}
	};

	cancelCBInvoices = () => {
		this.warningList = [];
		this.invoiceWrappers = [];
	};

	/**
	 * Method splits one line by coma using smart approach
	 */
	splitByComa = (line) => {
		try {
			let insideQuote = false, r = [], v = [];
			line.split('').forEach(function (character) {
				if (character === '"') {
					insideQuote = !insideQuote;
				} else {
					if (character === "," && !insideQuote) {
						r.push(v.join(''));
						v = [];
					} else {
						v.push(character);
					}
				}
			});
			r.push(v.join(''));
			return r;
		} catch (e) {
			_message('error', 'Actual Loader : Split by Coma Error : ' + e);
		}
	};

	///// UPLOAD AN EXAMPLE //////////
	renderedCallback() {
		Promise.all([
			loadScript(this, exceljs),
		]).catch(function (e) {
			_message(`error`, `BLME : Excel Backup load library ${e}`);
		});
	}

	async uploadExampleFile(event) {
		this.showSpinner = true;
		try {
			this.showSpinner = true;
			const fileName = 'Invoices Template ';
			let workbook = new ExcelJS.Workbook();
			let invoicesSheet = workbook.addWorksheet('Invoices', {views: [{state: 'frozen', ySplit: 1, xSplit: 0}]});
			let namingSheet = workbook.addWorksheet('Naming', {views: [{state: 'frozen', ySplit: 1, xSplit: 0}]});

			this.addInvoices(invoicesSheet);
			this.addNaming(namingSheet);
			/*getBudgetSheet(blSheet, this.summaryData, this.globalCluster);
			getPivotSheet(pivotSheet, this.summaryData, this.globalCluster);*/

			let data = await workbook.xlsx.writeBuffer();
			const blob = new Blob([data], {type: 'application/octet-stream'});
			let downloadLink = document.createElement("a");
			downloadLink.href = window.URL.createObjectURL(blob);
			downloadLink.target = '_blank';
			downloadLink.download = fileName + '.xlsx';
			downloadLink.click();
			this.showSpinner = false;
		} catch (e) {
			_message('error', 'BLME : Excel Backup Generate a File Error : ' + e);
			this.showSpinner = false;
		}
	};

	headerTitles = [
		{l: 'Number', w: 10},
		{l: 'Invoice Title', w: 30},
		{l: 'CB Account', w: 30},
		{l: 'Date', w: 10},
		{l: 'CB Period', w: 10},
		{l: 'CB Budget Line', w: 30},
		{l: 'Vendor', w: 20},
		{l: 'Line Title', w: 30},
		{l: 'Amount', w: 10}
	];

	getDefaultValueForExampleLine(idx) {
		switch (idx) {
			case 1:
				return '123';
			case 2:
				return 'Advertising costs';
			case 3:
				return Object.keys(this.dataMapping.accounts)[0];
			case 4:
				return '2023-01-08';
			case 5:
				return '1/23';
			case 6:
				return Object.keys(this.dataMapping.budgetLines)[0];
			case 7:
				return Object.keys(this.dataMapping.vendors)[0];
			case 8:
				return 'Some Details';
			case 9:
				return 1121;
		}

	};

	addInvoices = (blSheet) => {
		try {
			const firstRow = blSheet.getRow(1);
			const secondRow = blSheet.getRow(2);
			this.headerTitles.forEach((ht, idx) => {
				const column = blSheet.getColumn(idx + 1);
				column.width = ht.w;
				_setCell(firstRow.getCell(idx + 1), ht.l);

				const cellValue = this.getDefaultValueForExampleLine(idx + 1);
				_setCell(secondRow.getCell(idx + 1), cellValue);
			});
		} catch (e) {
			_message('error', 'Add Invoices Error : ' + e);
		}
	};

	addNaming = (blSheet) => {
		try {
			const dataMappings = [this.dataMapping.accounts, this.dataMapping.budgetLines, this.dataMapping.vendors];
			const titles = ['CB Accounts', 'CB Budget Lines', 'Vendors'];
			titles.forEach((title, idx) => {
				const listOfRecords = Object.keys(dataMappings[idx]);
				const column = blSheet.getColumn(idx + 1);
				column.width = 50;
				column.values = [title, ...listOfRecords];
			});
		} catch (e) {
			_message('error', 'Add Naming Error: ' + e);
		}
	};


	///// UPLOAD AN EXAMPLE //////////


}