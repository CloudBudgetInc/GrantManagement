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
import saveGrantBudgetLineServer from '@salesforce/apex/CBGMGrantPageController.saveGrantBudgetLineServer';
import isManagerServer from '@salesforce/apex/CBGMGrantPageController.isManagerServer';
import addBudgetLineServer from '@salesforce/apex/CBGMGrantPageController.addBudgetLineServer';
import getOrgVariableServer from '@salesforce/apex/CBGMGrantPageController.getOrgVariableServer';
import swapContractToOpportunityServer from '@salesforce/apex/CBGMGrantPageController.swapContractToOpportunityServer';
import getCBGrantIdFromOppGrantIdServer
	from '@salesforce/apex/CBGMGrantPageController.getCBGrantIdFromOppGrantIdServer';
import recalculateOpportunityAmountServer
	from '@salesforce/apex/CBGMGrantPageController.recalculateOpportunityAmountServer';
import {_applyDecStyle, _getCopy, _getSOFromObject, _message, _parseServerError} from "c/cbUtils";

import {NavigationMixin} from 'lightning/navigation';


export default class CBFundBudget extends NavigationMixin(LightningElement) {

	@api recordId;
	@track showSpinner = false;
	@track orgVariable = {};
	@track allYearBudgetLines = [];
	@track totalLine = {grantTotal: 0};
	@track budgetLines = [];
	@track groupedBudgetLines = [];
	@track selectedBYId;
	@track budgetYearSO = [];
	@track fundSO = [];
	@track showTable = false;
	@track budgetLineId = false;
	@track isManager = false; // if user is GM admit he can select funds

	///// FIND BUDGET //////
	@track showFindBudgetModal = false;
	@track targetBudgetLineId;
	@track availableFundIds = [];

	///// FIND BUDGET //////


	async connectedCallback() {
		this.showTable = false;
		this.fundSO = [];
		this.budgetLines = [];
		this.totalLine = {grantTotal: 0};
		this.allYearBudgetLines = [];
		_applyDecStyle();
		this.showSpinner = true;
		await this.getOrgVariable();
		await this.swapContractToOpportunity();
		await this.isUserGMManager();
		await this.getAnalytics();
		await this.getGrantBudgetLines();
		this.recalculateOpportunityAmount();
		this.showSpinner = false;
	};

	getOrgVariable = async () => {
		this.orgVariable = await getOrgVariableServer().catch(e => _parseServerError('Get Org Variable Error : ', e))
	};

	swapContractToOpportunity = async () => {
		this.recordId = await swapContractToOpportunityServer({contractOppId: this.recordId}).catch(e => _parseServerError('Swap ID Error' + e));
	};

	getAnalytics = async () => {
		await getAnalyticsServer({oppId: this.recordId})
			.then(analyticMap => {
				this.budgetYearSO = _getSOFromObject(analyticMap.budgetYearSO);
				this.fundSO = _getSOFromObject(analyticMap.fundSO);
				if (this.fundSO && this.fundSO.length > 0) this.availableFundIds = this.fundSO.reduce((r, so) => {
					r.push(so.value);
					return r;
				}, []);
			})
			.catch(e => _parseServerError('Get Analytics Error : ', e));
	};

	getGrantBudgetLines = async () => {
		await getGrantBudgetLinesServer({oppId: this.recordId})
			.then(allYearBudgetLines => {
				this.allYearBudgetLines = allYearBudgetLines;
				this.prepareGrantBudgetLines();
				this.showSpinner = false;
				this.showTable = true;
			})
			.catch(e => _parseServerError('Get Grant Budget Lines Error : ', e))
	};

	isUserGMManager = async () => {
		this.isManager = await isManagerServer();
	};

	prepareGrantBudgetLines = () => {
		try {
			this.showTable = false;
			if (!this.allYearBudgetLines || this.allYearBudgetLines.length === 0) {
				if (!this.selectedBYId) this.selectedBYId = this.budgetYearSO[0].value;
				return null;
			}
			if (!this.selectedBYId) this.selectedBYId = this.allYearBudgetLines[0].cb5__CBBudgetYear__c;
			this.budgetLines = this.allYearBudgetLines.filter(bl => bl.cb5__CBBudgetYear__c === this.selectedBYId);
			this.budgetLines.forEach(bl => bl.cb5__Value__c = 0);
			this.budgetLines = _getCopy(this.budgetLines);
			this.groupBudgetLines();
			this.recalculateTotalLineAndGlobalTotal();
			this.showTable = true;
		} catch (e) {
			_message('error', 'Prepare Table Error : ' + e);
		}
	};

	groupBudgetLines = () => {
		try {
			console.log('this.orgVariable = ' + JSON.stringify(this.orgVariable));
			console.log('this.orgVariable = ' + JSON.stringify(this.orgVariable));
			if (!this.budgetLines?.length) return null;
			if (!this.orgVariable?.cb5gm__GMGrantGrouping__c) {
				this.orgVariable = {cb5gm__GMGrantGrouping__c: 'singleGroup'};
			}
			const BLGroups = {};
			const defaultGroupName = 'Other';
			const fields = this.orgVariable.cb5gm__GMGrantGrouping__c.split('.');
			console.log('FIELDS: ' + fields);
			this.budgetLines.forEach(bl => {
				let key = fields.length === 1 ? bl[fields[0]] : bl[fields[0]]?.[fields[1]];
				console.log('KEY: ' + key);
				key = key ? key : defaultGroupName;
				let BLArray = BLGroups[key];
				if (!BLArray) {
					BLArray = [];
					BLGroups[key] = BLArray;
				}
				BLArray.push(bl);
			});
			this.groupedBudgetLines = Object.keys(BLGroups).reduce((r, key) => {
				r.push({
					groupName: key,
					budgetLines: BLGroups[key]
				});
				return r;
			}, []);
			if (this.groupedBudgetLines.length === 1) this.groupedBudgetLines[0].groupName = '';
		} catch (e) {
			_message('error', 'Group Budget Lines Error ' + e);
		}
	};

	recalculateOpportunityAmount = () => {
		recalculateOpportunityAmountServer({'oppId': this.recordId}).catch(e => _parseServerError('Recalculate Opportunity Amount Error: ', e));
	};

	recalculateTotalLineAndGlobalTotal = () => {
		try {
			this.totalLine = {cb5__CBAmounts__r: [], cb5__Value__c: 0, globalTotal: 0};
			let grantTotal = 0;
			if (!this.budgetLines || this.budgetLines.length === 0) return null;
			this.budgetLines.forEach(bl => bl.cb5__CBAmounts__r.forEach(amount => bl.cb5__Value__c += +amount.cb5__Value__c));
			this.allYearBudgetLines.forEach(bl => bl.cb5__CBAmounts__r.forEach(amount => grantTotal += +amount.cb5__Value__c));
			this.budgetLines = this.groupedBudgetLines.reduce((r, group) => {
				return [...r, ...group.budgetLines];
			}, []);
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
			this.totalLine.grantTotal = grantTotal;
		} catch (e) {
			_message('error', 'Recalculate Total Error ' + e);
		}
	};


	/**
	 * Handler for lost amount and BL fields
	 */
	saveBudgetLine = async (event) => {
		const property = event.target.name;
		let value = event.target.value;
		let id = event.target.label;

		if (['cb5__CBVariable1__c', 'Name'].includes(property)) {
			let bl = this.allYearBudgetLines.find(bl => bl.Id === id);
			bl[property] = value;

			const budgetLine = {Id: id};
			budgetLine[property] = value;
			await saveGrantBudgetLineServer({budgetLine}).catch(e => _parseServerError('Save Budget Line Error', e));
		} else {
			this.allYearBudgetLines.forEach(bl =>
				bl.cb5__CBAmounts__r.forEach(a => {
					if (a.Id === id) a.cb5__Value__c = value;
				})
			);
			this.prepareGrantBudgetLines();
			await saveGrantAmountServer({
				amount: {
					Id: id,
					cb5__Value__c: value
				},
				oppId: this.recordId
			}).catch(e => _parseServerError('Save Amount Line Error', e));
			this.recalculateOpportunityAmount();
		}
	};

	handleFilter = async (event) => {
		this.selectedBYId = event.target.value;
		this.prepareGrantBudgetLines();
	};

	addBudgetLines = () => {
		this.showSpinner = true;
		addBudgetLineServer({oppId: this.recordId, selectedBYId: this.selectedBYId})
			.then(async () => {
				await this.getGrantBudgetLines();
				const blId = this.budgetLines[this.budgetLines.length - 1].Id;
				this.openBudgetLine(null, blId);
			})
			.catch(e => _parseServerError('Add New Budget Line Error ', e))
	};

	///////// FIND FUND ///////
	findFund = (event) => {
		if (!this.availableFundIds || this.availableFundIds.length === 0) {
			_message('info', 'No funds available');
			return null;
		}
		this.targetBudgetLineId = event.target.value;
		this.showFindBudgetModal = true;
	};

	applyFund = async (event) => {
		try {
			const params = event.detail;
			const grantBL = this.budgetLines.find(bl => bl.Id === params.grantBudgetLineId);
			grantBL.cb5__CBVariable1__c = params.fundId;
			const saveEvent = {
				target: {
					name: 'cb5__CBVariable1__c',
					label: params.grantBudgetLineId,
					value: params.fundId,
				}
			};
			this.budgetLines = _getCopy(this.budgetLines);
			this.closeFindBudgetModal();
			await this.saveBudgetLine(saveEvent);
		} catch (e) {
			_message('error', 'Apply Fund Error ' + e);
		}
	};

	closeFindBudgetModal = () => this.showFindBudgetModal = false;

	///////// FIND FUND ///////

	openBudgetLine = (event, blId) => {
		this.budgetLineId = blId ? blId : event.target.dataset.id;
	};

	closeBudgetLine = () => {
		this.budgetLineId = undefined;
		this.connectedCallback();
	};

	redirectToBLM = async () => {
		const CBGrantId = await getCBGrantIdFromOppGrantIdServer({oppId: this.recordId});
		if (!CBGrantId) {
			_message('info', 'Something wrong');
			return null;
		}
		this[NavigationMixin.Navigate]({
			type: 'standard__navItemPage',
			attributes: {
				apiName: 'cb5__Budget_Lines'
			},
			state: {
				cb5_CBYear__c: this.selectedBYId,
				cb5_CBVariable2__c: CBGrantId
			}
		});

	};

	constructor() {
		super();
		this.addEventListener("closeFindBudgetModal", this.closeFindBudgetModal);
		this.addEventListener("closeBudgetLineModal", this.closeBudgetLine);
		this.addEventListener("applyFund", this.applyFund);
	}


}