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
//import getDataForMappingServer from '@salesforce/apex/CBActualLoaderPageController.getDataForMappingServer';
import getAnalyticsServer from '@salesforce/apex/CBGMFundPageController.getAnalyticsServer';
import getFundBudgetLinesServer from '@salesforce/apex/CBGMFundPageController.getFundBudgetLinesServer';
import generateFundBudgetLinesServer from '@salesforce/apex/CBGMFundPageController.generateFundBudgetLinesServer';
import saveFundAmountServer from '@salesforce/apex/CBGMFundPageController.saveFundAmountServer';
import getAllocationGrantsServer from '@salesforce/apex/CBGMFundPageController.getAllocationGrantsServer';
import getAllocationOperationalServer from '@salesforce/apex/CBGMFundPageController.getAllocationOperationalServer';
import updateOpportunityByTriggerServer from '@salesforce/apex/CBGMFundPageController.updateOpportunityByTriggerServer';
import recalculateTotalAmountsServer from '@salesforce/apex/CBGMFundPageController.recalculateTotalAmountsServer';
import getCBFundIdFromOppFundIdServer from '@salesforce/apex/CBGMFundPageController.getCBFundIdFromOppFundIdServer';
import recalculateFundBalanceBudgetServer
	from '@salesforce/apex/CBGMFundPageController.recalculateFundBalanceBudgetServer';
import {_applyDecStyle, _getCopy, _getSOFromObject, _message, _parseServerError} from "c/cbUtils";
import {NavigationMixin} from 'lightning/navigation';


export default class CBFundBudget extends NavigationMixin(LightningElement) {

	@api recordId;
	@track showSpinner = false;
	@track allCommittedBudgetLines = [];
	@track allGrantBudgetLines = [];
	@track allOperationalBudgetLines = [];
	@track grantBudgetLines = [];
	@track operationalBudgetLines = [];
	@track selectedBYId;
	@track budgetYearSO = [];
	@track fundSO = [];
	@track renderBudget = false;
	@track fundPlanLine = {
		Name: 'Committed Plan',
		cb5__CBAmounts__r: [],
		total: 0
	};
	@track fundBalanceLine = {
		Name: 'Remaining Fund Balance',
		cb5__CBAmounts__r: [],
		total: 0
	};


	async connectedCallback() {
		this.showSpinner = true;
		_applyDecStyle();
		await this.updateOpportunityByTrigger();
		await this.recalculateFundBalanceBudget();
		await this.getAnalytics();
		await this.getFundBudgetLines();
		this.generateCommittedBudgetLine();
		await this.getAllocationGrants();
		await this.getAllocationOperational();
		this.separateGrantBudgetLines();
		this.separateOperationalBudgetLines();
		this.calculateBalanceAmounts();
		this.showSpinner = false;
		this.recalculateTotalAmounts();
	};

	get renderGrantAllocationTable() {
		return this.grantBudgetLines && this.grantBudgetLines.length > 0;
	}

	get renderOperationalAllocationTable() {
		return this.operationalBudgetLines && this.operationalBudgetLines.length > 0;
	}

	updateOpportunityByTrigger = async () => {
		await updateOpportunityByTriggerServer({oppId: this.recordId}).catch(e => _parseServerError('Update Opportunity by Trigger Error : ', e));
	};

	getAnalytics = async () => {
		await getAnalyticsServer()
			.then(analyticMap => this.budgetYearSO = _getSOFromObject(analyticMap.budgetYearSO))
			.catch(e => _parseServerError('Get Analytics Error : ', e));
	};

	getFundBudgetLines = async () => {
		await getFundBudgetLinesServer({oppId: this.recordId})
			.then(budgetLines => {
				if (budgetLines && budgetLines.length > 0) this.renderBudget = true;
				this.allCommittedBudgetLines = budgetLines
			})
			.catch(e => _parseServerError('Get Budget Lines Error : ', e))
	};

	getAllocationGrants = async () => {
		await getAllocationGrantsServer({oppId: this.recordId})
			.then(allGrantBudgetLines => this.allGrantBudgetLines = allGrantBudgetLines)
			.catch(e => _parseServerError('Get Grant Allocation Error : ', e));
	};

	getAllocationOperational = async () => {
		await getAllocationOperationalServer({oppId: this.recordId})
			.then(allOperationalBudgetLines => {
				this.allOperationalBudgetLines = allOperationalBudgetLines;
			})
			.catch(e => _parseServerError('Get Operational Allocation Error : ', e));
	};

	recalculateTotalAmounts = () => {
		recalculateTotalAmountsServer({oppId: this.recordId}).catch(e => _message('error', 'Recalculate Fund Totals Error : ' + e));
	};
	recalculateFundBalanceBudget = async () => {
		await recalculateFundBalanceBudgetServer({oppId: this.recordId}).catch(e => _message('error', 'Recalculate Balance Budget Error : ' + e));
	};

	generateCommittedBudgetLine = () => {
		try {
			this.fundPlanLine.cb5__CBAmounts__r = [];
			this.fundPlanLine.total = 0;
			if (!this.allCommittedBudgetLines || this.allCommittedBudgetLines.length === 0) return null;
			if (!this.selectedBYId) this.selectedBYId = this.allCommittedBudgetLines[0].cb5__CBBudgetYear__c;
			this.allCommittedBudgetLines.forEach(bl => {
				bl.cb5__CBAmounts__r.forEach(amount => {
					if (amount.cb5__CBPeriod__r.cb5__CBBudgetYear__c === this.selectedBYId) {
						amount.label = amount.cb5__CBPeriod__r.Name;
						this.fundPlanLine.cb5__CBAmounts__r.push(amount);
						this.fundPlanLine.total += parseFloat(amount.cb5__Value__c);
					}
				})
			});
		} catch (e) {
			_message('error', 'Prepare Table Error : ' + e);
		}
	};

	/**
	 * Grant allocation grouped synthetic lines
	 */
	separateGrantBudgetLines = () => {
		try {
			this.grantBudgetLines = [];
			const grantBudgetLinesBY = this.allGrantBudgetLines.filter(bl => bl.cb5__CBBudgetYear__c === this.selectedBYId);
			if (grantBudgetLinesBY.length === 0) return null;
			const BLObject = {};
			const totalLine = {
				Name: 'TOTAL ALLOCATED',
				cb5__CBAmounts__r: [],
				cb5__Value__c: 0,
				styleClassText: 'totalValue',
				styleClassNumber: 'totalValue dec'
			};
			grantBudgetLinesBY.forEach(bl => {
				let groupGrantBudgetLine = BLObject[bl.cb5__CBVariable2__c];
				if (!groupGrantBudgetLine) {
					groupGrantBudgetLine = {
						Name: bl.cb5__CBVariable2__r.Name,
						cb5__CBAmounts__r: _getCopy(bl.cb5__CBAmounts__r),
						cb5__Value__c: 0,
						styleClassNumber: 'dec',
						id: bl?.cb5__CBVariable2__r?.cb5__ExtId__c
					};
					groupGrantBudgetLine.cb5__CBAmounts__r.forEach(a => a.cb5__Value__c = 0);
					BLObject[bl.cb5__CBVariable2__c] = groupGrantBudgetLine;
				}
				bl.cb5__CBAmounts__r.forEach((amount, i) => {
					let oldAmount = totalLine.cb5__CBAmounts__r[i];
					if (!oldAmount) {
						oldAmount = {cb5__Value__c: 0};
						totalLine.cb5__CBAmounts__r[i] = oldAmount;
					}
					totalLine.cb5__CBAmounts__r[i].cb5__Value__c = +oldAmount.cb5__Value__c + +amount.cb5__Value__c;
					totalLine.cb5__Value__c += +amount.cb5__Value__c;

					groupGrantBudgetLine.cb5__CBAmounts__r[i].cb5__Value__c += +amount.cb5__Value__c;
					groupGrantBudgetLine.cb5__Value__c += +amount.cb5__Value__c;
				});
			});
			this.grantBudgetLines = [totalLine, ...Object.values(BLObject)];
		} catch (e) {
			_message('error', 'Generate Grant Budget Lines Error : ' + e);
		}
	};

	separateOperationalBudgetLines = () => {
		try {
			this.operationalBudgetLines = [];
			const operationalBudgetLinesBY = this.allOperationalBudgetLines.filter(bl => bl.cb5__CBBudgetYear__c === this.selectedBYId);
			if (operationalBudgetLinesBY.length === 0) return null;
			const totalLine = {
				Name: 'TOTAL OPERATIONAL',
				cb5__CBAmounts__r: [],
				cb5__Value__c: 0,
				styleClassText: 'totalValue',
				styleClassNumber: 'totalValue dec'
			};
			operationalBudgetLinesBY.forEach(bl => {
				bl.cb5__Value__c = 0;
				bl.styleClassNumber = 'dec';
				bl.cb5__CBAmounts__r.forEach((amount, i) => {
					let oldAmount = totalLine.cb5__CBAmounts__r[i];
					if (!oldAmount) {
						oldAmount = {cb5__Value__c: 0};
						totalLine.cb5__CBAmounts__r[i] = oldAmount;
					}
					totalLine.cb5__CBAmounts__r[i].cb5__Value__c = +oldAmount.cb5__Value__c + +amount.cb5__Value__c;
					bl.cb5__Value__c += +amount.cb5__Value__c;
					totalLine.cb5__Value__c += +amount.cb5__Value__c;
				});
			});
			this.operationalBudgetLines = [totalLine, ...operationalBudgetLinesBY];
		} catch (e) {
			_message('error', 'Generate Operational Budget Lines Error : ' + e);
		}
	};


	calculateBalanceAmounts = () => {
		try {
			const allBalanceAmounts = {}; // key is periodId, value is CB amount
			let rest = 0;
			let allAllocations = [...this.allGrantBudgetLines, ...this.allOperationalBudgetLines];
			const allAllocatedAmountsMap = allAllocations.reduce((r, bl) => { // key is grant amount period id. value is amount
				bl.cb5__CBAmounts__r.forEach(a => {
					let value = r[a.cb5__CBPeriod__c];
					if (!value) value = 0;
					r[a.cb5__CBPeriod__c] = +value + +a.cb5__Value__c;
				});
				return r;
			}, {});
			this.allCommittedBudgetLines.forEach(bl => {
				bl.cb5__CBAmounts__r.forEach(amount => {
					const balanceAmount = _getCopy(amount);
					['cb5__CBBudgetLine__c', 'Id', 'cb5__CBPeriod__r', 'label'].forEach(field => delete balanceAmount[field]);
					allBalanceAmounts[amount.cb5__CBPeriod__c] = balanceAmount;
					let granted = allAllocatedAmountsMap[amount.cb5__CBPeriod__c] || 0;
					//console.log('Granted = ' + granted);
					let balanceValue = rest + +amount.cb5__Value__c - granted;
					//console.log('balanceValue = ' + balanceValue);
					balanceAmount.cb5__Value__c = balanceValue;
					if (balanceValue < 0) balanceAmount.overBudget = true;
					rest = balanceValue;
				});
			});
			//console.log('allBalanceAmounts = ' + JSON.stringify(allBalanceAmounts));
			this.fundBalanceLine.cb5__CBAmounts__r = [];
			this.fundPlanLine.cb5__CBAmounts__r.forEach(planAmount => {
				let balanceAmount = allBalanceAmounts[planAmount.cb5__CBPeriod__c];
				balanceAmount.cb5__CBPeriod__c = planAmount.cb5__CBPeriod__c;
				this.fundBalanceLine.cb5__CBAmounts__r.push(balanceAmount);
			});
		} catch (e) {
			_message('error', 'Generate Balance Line Error' + e);
		}

	};

	///////////////// HANDLERS /////////////////////
	handleFilter = async (event) => {
		this.selectedBYId = event.target.value;
		this.separateGrantBudgetLines();
		this.separateOperationalBudgetLines();
		this.generateCommittedBudgetLine();
		this.calculateBalanceAmounts();
	};
	/**
	 * Handler for lost amount
	 */
	saveAmount = async (event) => {
		const amountId = event.target.name;
		let amountValue = event.target.value;
		if (!amountValue) amountValue = 0;
		let amountNeedToBeSaved;
		this.fundPlanLine.total = 0;
		this.fundPlanLine.cb5__CBAmounts__r.forEach(amount => {
			if (amount.Id === amountId) {
				amount.cb5__Value__c = amountValue;
				amountNeedToBeSaved = amount;
			}
			this.fundPlanLine.total += +amount.cb5__Value__c;
		});
		console.log('saveFundAmountServer : ' + JSON.stringify(amountNeedToBeSaved));
		await saveFundAmountServer({amount: amountNeedToBeSaved}).catch(e => _parseServerError('Save Amount Error', e));
		this.calculateBalanceAmounts();
		this.recalculateTotalAmounts();
	};

	/**
	 * Method creates budget lines for whole budget years
	 */
	generateBudgetLines = async () => {
		try {
			this.showSpinner = true;
			await generateFundBudgetLinesServer({oppId: this.recordId})
				.catch(e => _parseServerError('Generate Budget Lines Error : ' + e));
			await this.connectedCallback();
			_message('success', 'Generated');
			this.showSpinner = false;
		} catch (e) {
			_message('error', 'Generate BL Error : ' + e);
		}
	};
	///////////////// HANDLERS /////////////////////

	redirectToBLM = async () => {
		const CBFundId = await getCBFundIdFromOppFundIdServer({oppId: this.recordId});
		if (!CBFundId) {
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
				cb5_CBVariable1__c: CBFundId
			}
		});

	};

	redirectToFund = (event) => {
		this[NavigationMixin.Navigate]({
			type: 'standard__recordPage',
			attributes: {
				recordId: event.target.name,
				objectApiName: 'Opportunity',
				actionName: 'view'
			}
		});
	}


}