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
import findBudgetServer from '@salesforce/apex/CBGMFundPageController.findBudgetServer';
import {_applyDecStyle, _message, _parseServerError} from "c/cbUtils";


export default class CBFindBudget extends LightningElement {

	@api grantBudgetLineId;
	@api availableFundIds;
	@track showSpinner = false;
	@track grantBudgetLine = {cb5__CBAmounts__r: []};
	@track fundBudgetLines = [];
	@track showTable = false;


	async connectedCallback() {
		_applyDecStyle();
		this.showSpinner = true;
		await this.findBudget();
		this.showSpinner = false;
	};

	findBudget = () => {
		findBudgetServer({gblId: this.grantBudgetLineId, availableFundIds: this.availableFundIds})
			.then(budgetLines => {
				try {
					if (!budgetLines || budgetLines.size === 0) return null;
					this.grantBudgetLine = this.prepareBudgetLine(budgetLines.shift());
					const updatedBudgetLines = [];
					budgetLines.forEach(bl => updatedBudgetLines.push(this.prepareBudgetLine(bl)));
					this.fundBudgetLines = updatedBudgetLines;
					this.compareGrantAndFundBalance();
					this.showTable = true;
				} catch (e) {
					_message('error', 'FBS Callback Error ' + e);
				}
			})
			.catch(e => _parseServerError('Find Budget Error ', e))
	};

	prepareBudgetLine = (bl) => {
		bl.total = bl.cb5__CBAmounts__r.reduce((r, a) => {
			a.label = a.cb5__CBPeriod__r?.Name;
			r += +a.cb5__Value__c;
			return r;
		}, 0);
		return bl;
	};

	compareGrantAndFundBalance = () => {
		try {
			const grant = this.grantBudgetLine;
			const amountsSize = grant.cb5__CBAmounts__r.length;
			this.fundBudgetLines.forEach(fund => {
				fund.iconName = 'utility:check';
				if (fund.total < grant.total) {
					delete fund.iconName;
					return null;
				}
				let availableRest = 0;
				for (let i = 0; i < amountsSize; i++) {
					const grantNeeded = grant.cb5__CBAmounts__r[i].cb5__Value__c;
					const fundHas = fund.cb5__CBAmounts__r[i].cb5__Value__c + availableRest;
					if (grantNeeded > fundHas) {
						delete fund.iconName;
						break;
					}
					availableRest = availableRest + fundHas - grantNeeded;
				}
			})
		} catch (e) {
			_message('error', 'Compare Fund & Grant Error ' + e);
		}
	};

	applyFund = (event) => {
		this.dispatchEvent(new CustomEvent('applyFund', {
			bubbles: true,
			composed: true,
			detail: {fundId: event.target.value, grantBudgetLineId: this.grantBudgetLineId}
		}));
	};

	close = () => {
		this.dispatchEvent(new CustomEvent('closeFindBudgetModal', {
			bubbles: true,
			composed: true,
			//detail: {reloadMainComponent: this.reloadMainComponent}
		}));
	};


}