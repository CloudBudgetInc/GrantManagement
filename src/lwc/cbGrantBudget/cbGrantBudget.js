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
import getAnalyticsServer from '@salesforce/apex/CBGMGrantPageController.getAnalyticsServer';
import getGrantBudgetLinesServer from '@salesforce/apex/CBGMGrantPageController.getGrantBudgetLinesServer';
import saveGrantAmountServer from '@salesforce/apex/CBGMGrantPageController.saveGrantAmountServer';
import saveBudgetLineServer from '@salesforce/apex/CBGMGrantPageController.saveBudgetLineServer';
import addBudgetLineServer from '@salesforce/apex/CBGMGrantPageController.addBudgetLineServer';
import {_applyDecStyle, _getCopy, _getSOFromObject, _message, _parseServerError} from "c/cbUtils";


export default class CBFundBudget extends LightningElement {

	@api recordId;
	@track showSpinner = false;
	@track allYearBudgetLines = [];
	@track totalLine = {};
	@track budgetLines = [];
	@track selectedBYId;
	@track budgetYearSO = [];
	@track fundSO = [];


	async connectedCallback() {
		_applyDecStyle();
		this.showSpinner = true;
		await this.getAnalytics();
		await this.getGrantBudgetLines();
		this.showSpinner = false;
	};

	getAnalytics = async () => {
		await getAnalyticsServer({oppId: this.recordId})
			.then(analyticMap => {
				this.budgetYearSO = _getSOFromObject(analyticMap.budgetYearSO);
				this.fundSO = _getSOFromObject(analyticMap.fundSO);
			})
			.catch(e => _parseServerError('Get Analytics Error : ', e));
	};

	getGrantBudgetLines = async () => {
		await getGrantBudgetLinesServer({oppId: this.recordId})
			.then(allYearBudgetLines => {
				this.allYearBudgetLines = allYearBudgetLines;
				this.prepareTable();
				this.showSpinner = false;
			})
			.catch(e => _parseServerError('Get Grant Budget Lines Error : ', e))
	};

	prepareTable = () => {
		try {
			if (!this.allYearBudgetLines || this.allYearBudgetLines.length === 0) return null;
			if (!this.selectedBYId) this.selectedBYId = this.allYearBudgetLines[0].cb5__CBBudgetYear__c;
			this.budgetLines = this.allYearBudgetLines.filter(bl => bl.cb5__CBBudgetYear__c === this.selectedBYId);
			this.budgetLines.forEach(bl => bl.cb5__Value__c = 0);
			this.recalculateTotals();
			this.budgetLines = _getCopy(this.budgetLines);
		} catch (e) {
			_message('error', 'Prepare Table Error : ' + e);
		}
	};

	recalculateTotals = () => {
		try {
			this.totalLine = {cb5__CBAmounts__r: [], cb5__Value__c: 0};
			if (!this.budgetLines || this.budgetLines.length === 0) return null;
			this.budgetLines.forEach(bl => bl.cb5__CBAmounts__r.forEach(amount => bl.cb5__Value__c += +amount.cb5__Value__c));
			this.totalLine = this.budgetLines.reduce((r, bl) => {
				r.cb5__Value__c += +bl.cb5__Value__c;
				bl.cb5__CBAmounts__r.forEach((amount, i) => {
					let totalLineAmount = r.cb5__CBAmounts__r[i];
					if (!totalLineAmount) {
						totalLineAmount = {cb5__Value__c: 0, label: amount.cb5__CBPeriod__r.Name};
						r.cb5__CBAmounts__r.push(totalLineAmount);
					}
					totalLineAmount.cb5__Value__c += +amount.cb5__Value__c;
				});
				return r;
			}, {cb5__CBAmounts__r: [], cb5__Value__c: 0});
		} catch (e) {
			_message('error', 'Recalculate Total Error ' + e);
		}
	};


	/**
	 * Handler for lost amount
	 */
	saveBudgetLine = async (event) => {
		const property = event.target.name;
		let value = event.target.value;
		let blId = event.target.label;

		if (['cb5__CBVariable1__c', 'Name'].includes(property)) {
			const budgetLine = {Id: blId};
			budgetLine[property] = value;
			await saveBudgetLineServer({budgetLine}).catch(e => _parseServerError('Save Budget Line Error', e));
		} else {
			await saveGrantAmountServer({
				amount: {
					Id: blId,
					cb5__Value__c: value
				}
			}).catch(e => _parseServerError('Save Amount Line Error', e));
		}
	};

	handleFilter = async (event) => {
		this.selectedBYId = event.target.value;
		this.prepareTable();
	};

	addBudgetLines = () => {
		this.showSpinner = true;
		addBudgetLineServer({oppId: this.recordId, selectedBYId: this.selectedBYId})
			.then(() => this.getGrantBudgetLines())
			.catch(e => _parseServerError('Add New Budget Line Error ', e))
	};


}