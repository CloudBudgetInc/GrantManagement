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
import {_applyDecStyle, _message, _parseServerError, _getSOFromObject} from "c/cbUtils";


export default class CBFundBudget extends LightningElement {

	@api recordId;
	@track showSpinner = false;
	@track budgetLines = [];
	@track selectedBYId;
	@track budgetYearSO = [];
	@track fundSO = [];
	@track fundPlanLine = {
		label: 'Committed Plan',
		amounts: [],
		total: 0
	};


	async connectedCallback() {
		_applyDecStyle();
		await this.getAnalytics();
		await this.getFundBudgetLines();
	};

	getAnalytics = async () => {
		await getAnalyticsServer()
			.then(analyticMap => this.budgetYearSO = _getSOFromObject(analyticMap.budgetYearSO))
			.catch(e => _parseServerError('Get Analytics Error : ', e));
	};

	getFundBudgetLines = async () => {
		await getFundBudgetLinesServer({oppId: this.recordId})
			.then(budgetLines => {
				this.budgetLines = budgetLines;
				this.prepareTable();
			})
			.catch(e => _parseServerError('Get Budget Lines Error : ', e))
	};

	generateBudgetLines = async () => {
		this.showSpinner = true;
		await generateFundBudgetLinesServer({oppId: this.recordId})
			.error(e => _parseServerError('Generate Budget Lines Error : ' + e));
		await this.getFundBudgetLines();
		_message('success', 'Generated');
		this.showSpinner = false;
	};

	prepareTable = () => {
		try {
			this.fundPlanLine.amounts = [];
			this.fundPlanLine.total = 0;
			if (!this.budgetLines || this.budgetLines.length === 0) return null;
			if (!this.selectedBYId) this.selectedBYId = this.budgetLines[0].cb5__CBBudgetYear__c;
			this.budgetLines.forEach(bl => {
				bl.cb5__CBAmounts__r.forEach(amount => {
					if (amount.cb5__CBPeriod__r.cb5__CBBudgetYear__c === this.selectedBYId) {
						amount.label = amount.cb5__CBPeriod__r.Name;
						this.fundPlanLine.amounts.push(amount);
						this.fundPlanLine.total += parseFloat(amount.cb5__Value__c);
					}
				})
			});
		} catch (e) {
			_message('error', 'Prepare Table Error : ' + e);
		}
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
		this.fundPlanLine.amounts.forEach(amount => {
			if (amount.Id === amountId) {
				amount.cb5__Value__c = amountValue;
				amountNeedToBeSaved = amount;
			}
			this.fundPlanLine.total += +amount.cb5__Value__c;
		});

		await saveFundAmountServer({amount: amountNeedToBeSaved}).catch(e => _parseServerError('Save Amount Error', e));
	};

	handleFilter = async (event) => {
		this.selectedBYId = event.target.value;
		this.prepareTable();
	}


}