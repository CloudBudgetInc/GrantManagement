/** 
Copyright (c) 2022, CloudBudget, Inc.
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


public with sharing class CBGMOpportunityDomain {

	/**
	 * Method recalculates total amount for Opportunity based on lines
	 * TODO: DRY
	 * @param oppId
	 */
	public static void recalculateTotalAmounts(String oppId) {

		Opportunity opportunity = [SELECT Id, RecordType.Name FROM Opportunity WHERE Id = :oppId];

		if (opportunity.RecordType.Name == 'Fund') {
			List<cb5__CBVariable1__c> vars1 = [SELECT Id FROM cb5__CBVariable1__c WHERE cb5__ExtId__c = :oppId];
			if (vars1.size() == 0) return ;
			cb5__CBVariable1__c var1 = vars1[0];
			List<AggregateResult> committed = [
					SELECT SUM(cb5__Value__c) cb5__Value__c
					FROM cb5__CBAmount__c
					WHERE cb5__CBBudgetLine__r.cb5__CBScenario__r.Name = :CBGMConst.BASE_SCENARIO_NAME
					AND cb5__CBBudgetLine__r.cb5__CBSubAccountName__c = 'Fund'
					AND cb5__CBBudgetLine__r.cb5__CBVariable1__c = :var1.Id
			];
			List<AggregateResult> granted = [
					SELECT SUM(cb5__Value__c) cb5__Value__c
					FROM cb5__CBAmount__c
					WHERE cb5__CBBudgetLine__r.cb5__CBScenario__r.Name = :CBGMConst.BASE_SCENARIO_NAME
					AND cb5__CBBudgetLine__r.cb5__CBSubAccountName__c != 'Fund'
					AND cb5__CBBudgetLine__r.cb5__CBVariable1__c = :var1.Id
			];
			opportunity.AmountCommitted__c = opportunity.AmountAppliedFor__c = 0;
			opportunity.AmountCommitted__c = committed.size() > 0 ? (Decimal) committed[0].get('cb5__Value__c') : 0;
			opportunity.AmountAppliedFor__c = granted.size() > 0 ? (Decimal) granted[0].get('cb5__Value__c') : 0;
		}

		if (opportunity.RecordType.Name == 'Grant') {
			List<cb5__CBVariable2__c> vars2 = [SELECT Id FROM cb5__CBVariable2__c WHERE cb5__ExtId__c = :oppId];
			if (vars2.size() == 0) {
				opportunity.Amount = 0;
			} else {
				cb5__CBVariable2__c var2 = vars2[0];
				List<AggregateResult> ags = [
						SELECT SUM(cb5__Value__c) cb5__Value__c
						FROM cb5__CBAmount__c
						WHERE cb5__CBBudgetLine__r.cb5__CBScenario__r.Name = :CBGMConst.BASE_SCENARIO_NAME
						AND cb5__CBBudgetLine__r.cb5__CBSubAccountName__c != 'Fund'
						AND cb5__CBBudgetLine__r.cb5__CBVariable2__c = :var2.Id
				];
				if (ags.size() > 0) {
					opportunity.Amount = (Decimal) ags[0].get('cb5__Value__c');
				}
			}
		}

		/// ACTUAL
		List<AggregateResult> ags = [
				SELECT SUM(cb5__Amount__c) cb5__Value__c
				FROM cb5__CBInvoiceLine__c
				WHERE cb5__CBInvoice__r.cb5__CBVariable1__r.cb5__ExtId__c = :oppId
				OR cb5__CBInvoice__r.cb5__CBVariable2__r.cb5__ExtId__c = :oppId
		];
		if (ags.size() > 0) {
			opportunity.AmountPaid__c = (Decimal) ags[0].get('cb5__Value__c');
		} else {
			opportunity.AmountPaid__c = 0;
		}
		update opportunity;
	}

	private static Map<Id, Opportunity> oppMap;
	public static void populateOpportunityMap(Set<Id> oppIds) {
		oppMap = new Map<Id, Opportunity>();
		for (Opportunity opp : [
				SELECT Id,Name,RecordType.Name,CBAccount__c,CBDivision__c,CBVariable3__c,CBVariable4__c,CBVariable5__c,StageName
				FROM Opportunity
				WHERE Id = :oppIds
		]) oppMap.put(opp.Id, opp);
	}

	/**
	 * Method sync Opportunity and CBVariable1 & CBVariable2
	 * TODO: DRY
	 * @param oppId
	 */
	public static void updateCBMapping(Id oppId) {
		System.debug('Update Mapping: ' + oppId);
		Opportunity opportunity = oppMap.get(oppId);
		System.debug('MAP TRIGGER FOR ' + opportunity.Name + ' => ' + opportunity.RecordType.Name);
		if (opportunity.RecordType.Name == 'Fund') {
			List<cb5__CBVariable1__c> variable1s = [SELECT Id FROM cb5__CBVariable1__c WHERE cb5__ExtId__c = :oppId];
			if (variable1s.size() == 0) {
				insert new cb5__CBVariable1__c(Name = opportunity.Name, cb5__ExtId__c = oppId);
			} else {
				cb5__CBVariable1__c var1 = variable1s[0];
				var1.Name = opportunity.Name;
				update var1;
			}
		}
		if (opportunity.RecordType.Name == 'Grant') {
			List<cb5__CBVariable2__c> variable2s = [SELECT Id FROM cb5__CBVariable2__c WHERE cb5__ExtId__c = :oppId];
			System.debug('variable2s = ' + variable2s);
			if (variable2s.size() == 0) {
				System.debug('INSERT VAR2');
				insert new cb5__CBVariable2__c(Name = opportunity.Name, cb5__ExtId__c = oppId);
			} else {
				cb5__CBVariable2__c var2 = variable2s[0];
				var2.Name = opportunity.Name;
				update var2;
			}
		}
	}

	/**
	 * Method sync budget Line analytics and Opportunity analytics
	 *
	 * @param oppId
	 */
	public static void updateBudgetLines(Id oppId) {
		Opportunity opportunity = oppMap.get(oppId);
		List<cb5__CBBudgetLine__c> budgetLines;
		if (opportunity.RecordType.Name == 'Fund') {
			budgetLines = [
					SELECT Id,cb5__Lock__c
					FROM cb5__CBBudgetLine__c
					WHERE cb5__CBVariable1__r.cb5__ExtId__c = :oppId
					AND ((cb5__CBScenario__r.Name = :CBGMConst.BASE_SCENARIO_NAME AND cb5__CBSubAccountName__c = 'Fund') OR cb5__CBScenario__r.Name = :CBGMConst.BALANCE_FUND_SCENARIO_NAME)
			];
		}
		if (opportunity.RecordType.Name == 'Grant') {
			budgetLines = [
					SELECT Id,cb5__Lock__c
					FROM cb5__CBBudgetLine__c
					WHERE cb5__CBVariable2__r.cb5__ExtId__c = :oppId AND cb5__CBScenario__r.Name = :CBGMConst.BASE_SCENARIO_NAME AND cb5__CBSubAccountName__c != 'Fund'
			];
		}
		if (budgetLines == null || budgetLines.size() == 0) return;
		List<cb5__CBBudgetLine__c> lockedLines = new List<cb5__CBBudgetLine__c>();
		for (cb5__CBBudgetLine__c bl : budgetLines) {
			if (bl.cb5__Lock__c != null) {
				bl.cb5__Lock__c = null;
				lockedLines.add(bl);
			}
		}
		update lockedLines;
		for (cb5__CBBudgetLine__c bl : budgetLines) {
			bl.cb5__Status__c = opportunity.StageName;
			if (opportunity.CBAccount__c != null) bl.cb5__CBAccount__c = opportunity.CBAccount__c;
			if (opportunity.CBDivision__c != null) bl.cb5__CBDivision__c = opportunity.CBDivision__c;
			if (opportunity.CBVariable3__c != null) bl.cb5__CBVariable3__c = opportunity.CBVariable3__c;
			if (opportunity.CBVariable4__c != null) bl.cb5__CBVariable4__c = opportunity.CBVariable4__c;
			if (opportunity.CBVariable5__c != null) bl.cb5__CBVariable5__c = opportunity.CBVariable5__c;
		}
		update budgetLines;
		for (cb5__CBBudgetLine__c bl : lockedLines) bl.cb5__Lock__c = 'Editing';
		update lockedLines;
	}

	public static void updateContractValues(Id oppId) {
		List<Contract> contracts = [SELECT Amount__c,StartDate FROM Contract WHERE Opportunity__c = :oppId];
		if (contracts.size() == 0) return ; // it means that users do not use Contracts as a source
		List<cb5__CBAmount__c> amounts = [
				SELECT Id,cb5__CBPeriod__c
				FROM cb5__CBAmount__c
				WHERE cb5__CBBudgetLine__r.cb5__CBVariable1__r.cb5__ExtId__c = :oppId AND cb5__CBBudgetLine__r.cb5__CBScenario__r.Name = :CBGMConst.BASE_SCENARIO_NAME AND cb5__CBBudgetLine__r.cb5__CBSubAccountName__c = 'Fund'
		];
		if (amounts.size() == 0) return ;

		Map<Date, Id> dateToCBPeriodIdMap = new Map<Date, Id>();
		for (cb5__CBPeriod__c p : [SELECT Id, cb5__Start__c FROM cb5__CBPeriod__c ORDER BY cb5__Start__c]) dateToCBPeriodIdMap.put(p.cb5__Start__c, p.Id);
		Map<Id, Decimal> periodIdAmountMap = new Map<Id, Decimal>();
		for (Contract ctr : contracts) {
			for (Date pDate : dateToCBPeriodIdMap.keySet()) {
				if (ctr.StartDate <= pDate) {
					Id periodId = dateToCBPeriodIdMap.get(pDate);
					Decimal oldAmount = periodIdAmountMap.get(periodId);
					if (oldAmount == null) oldAmount = 0;
					periodIdAmountMap.put(periodId, oldAmount + ctr.Amount__c);
					break;
				}
			}
		}

		for (cb5__CBAmount__c a : amounts) {
			Decimal newValue = periodIdAmountMap.get(a.cb5__CBPeriod__c);
			a.cb5__Value__c = newValue == null ? 0 : newValue;
		}

		update amounts;

	}

	public static void updateOpportunityWarnings(Id oppId) {
		CBGMWarningsService.updateWarnings(new List<String>{
				oppId
		});
	}

}