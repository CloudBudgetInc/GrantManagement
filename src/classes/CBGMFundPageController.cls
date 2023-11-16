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


public with sharing class CBGMFundPageController {

	@AuraEnabled
	public static Map<String, Map<String, String>> getAnalyticsServer() {
		Map<String, Map<String, String>> r = new Map<String, Map<String, String>>();
		Map<String, String> bYears = new Map<String, String>();
		for (cb5__CBBudgetYear__c budgetYear : [SELECT Id, Name FROM cb5__CBBudgetYear__c ORDER BY Name]) {
			bYears.put(budgetYear.Id, budgetYear.Name);
		}
		r.put('budgetYearSO', bYears);
		return r;
	}

	@AuraEnabled
	public static List<cb5__CBBudgetLine__c> getFundBudgetLinesServer(String oppId) {
		return [
				SELECT Id, Name, cb5__CBBudgetYear__r.Name, cb5__CBBudgetYear__c, (
						SELECT Id, cb5__Value__c, cb5__CBPeriod__c, cb5__CBPeriod__r.cb5__CBBudgetYear__r.Name, cb5__CBPeriod__r.Name
						FROM cb5__CBAmounts__r
						ORDER BY cb5__CBPeriod__r.cb5__Start__c
				)
				FROM cb5__CBBudgetLine__c
				WHERE cb5__CBScenario__r.Name = :CBGMConst.COMMITTED_FUND_SCENARIO_NAME
				AND cb5__CBVariable1__r.cb5__ExtId__c = :oppId
				ORDER BY cb5__CBBudgetYear__r.Name
		];
	}

	/**
	 * TODO Budget line wrapper to avoid DML in a loop
	 *
	 * @param oppId selected opportunity Id
	 */
	@AuraEnabled
	public static void generateFundBudgetLinesServer(String oppId) {
		Opportunity opp = [SELECT Id, Name FROM Opportunity WHERE Id = :oppId];
		String var1Id = [SELECT Id FROM cb5__CBVariable1__c WHERE cb5__ExtId__c = :oppId][0].Id;
		String scenarioId = [SELECT Id FROM cb5__CBScenario__c WHERE Name = :CBGMConst.COMMITTED_FUND_SCENARIO_NAME][0].Id;
		String accountId = [SELECT Id FROM cb5__CBAccount__c WHERE Name = :CBGMConst.DEFAULT_FUNDING_ACCOUNT_NAME][0].Id;
		List<cb5__CBBudgetLine__c> budgetLines = new List<cb5__CBBudgetLine__c>();

		for (cb5__CBBudgetYear__c budgetYear : [SELECT Id, (SELECT Id, Name FROM cb5__CBPeriods__r) FROM cb5__CBBudgetYear__c ORDER BY Name]) {
			cb5__CBBudgetLine__c newBL = new cb5__CBBudgetLine__c(cb5__CBScenario__c = scenarioId, cb5__CBBudgetYear__c = budgetYear.Id, cb5__CBVariable1__c = var1Id,
					cb5__CBAccount__c = accountId, cb5__Value__c = 0, Name = opp.Name, cb5__DrillDownIds__c = oppId);
			insert newBL;
			List<cb5__CBAmount__c> amounts = new List<cb5__CBAmount__c>();
			for (cb5__CBPeriod__c period : budgetYear.cb5__CBPeriods__r) {
				amounts.add(new cb5__CBAmount__c(cb5__Value__c = 0, cb5__CBPeriod__c = period.Id, cb5__CBBudgetLine__c = newBL.Id));
			}
			insert amounts;
		}
	}

	@AuraEnabled
	public static void saveFundAmountServer(cb5__CBAmount__c amount) {
		update amount;
	}

	@AuraEnabled
	public static List<cb5__CBBudgetLine__c> getAllocationGrantsServer(String oppId) {
		return [
				SELECT Id, Name, cb5__CBVariable1__c, cb5__CBVariable2__c, cb5__CBVariable2__r.Name, cb5__CBBudgetYear__r.Name, cb5__CBBudgetYear__c, cb5__Value__c, (
						SELECT Id, cb5__Value__c, cb5__CBPeriod__c, cb5__CBPeriod__r.cb5__CBBudgetYear__r.Name, cb5__CBPeriod__r.Name
						FROM cb5__CBAmounts__r
						ORDER BY cb5__CBPeriod__r.cb5__Start__c
				)
				FROM cb5__CBBudgetLine__c
				WHERE cb5__CBScenario__r.Name = :CBGMConst.GRANT_PLAN_SCENARIO_NAME
				AND cb5__CBVariable1__r.cb5__ExtId__c = :oppId
				ORDER BY cb5__CBBudgetYear__r.Name
		];
	}

	@AuraEnabled
	public static void saveFundBalanceBudgetLineServer(List<cb5__CBAmount__c> amounts, String oppId, String selectedBYId) {
		String balanceScenarioId = [SELECT Id FROM cb5__CBScenario__c WHERE Name = :CBGMConst.BALANCE_FUND_SCENARIO_NAME][0].Id;
		cb5__CBVariable1__c fund = [SELECT Id, Name FROM cb5__CBVariable1__c WHERE cb5__ExtId__c = :oppId][0];
		String accountId = [SELECT Id FROM cb5__CBAccount__c WHERE Name = :CBGMConst.DEFAULT_FUNDING_ACCOUNT_NAME][0].Id;
		delete [
				SELECT Id
				FROM cb5__CBBudgetLine__c
				WHERE cb5__CBBudgetYear__c = :selectedBYId
				AND cb5__CBVariable1__c = :fund.Id
				AND cb5__CBScenario__c = :balanceScenarioId
		];
		cb5__CBBudgetLine__c budgetLine = new cb5__CBBudgetLine__c();
		budgetLine.cb5__CBScenario__c = balanceScenarioId;
		budgetLine.cb5__CBVariable1__c = fund.Id;
		budgetLine.Name = fund.Name;
		budgetLine.cb5__CBBudgetYear__c = selectedBYId;
		budgetLine.cb5__CBAccount__c = accountId;
		insert budgetLine;
		for (cb5__CBAmount__c amount : amounts) amount.cb5__CBBudgetLine__c = budgetLine.Id;
		insert amounts;
	}

	@AuraEnabled
	public static List<cb5__CBBudgetLine__c> findBudgetServer(String gblId, List<String> availableFundIds) {
		List<cb5__CBBudgetLine__c> r = new List<cb5__CBBudgetLine__c>();
		System.debug('gblId = ' + gblId + ' availableFundIds = ' + availableFundIds);
		if (availableFundIds == null || availableFundIds.size() == 0) return r;

		cb5__CBBudgetLine__c grantBudgetLine = [ // grant budget Line
				SELECT Id,Name,cb5__CBBudgetYear__c,cb5__CBVariable1__c,cb5__CBVariable2__c, (SELECT Id, cb5__CBPeriod__c, cb5__Value__c, cb5__CBPeriod__r.Name FROM cb5__CBAmounts__r)
				FROM cb5__CBBudgetLine__c
				WHERE Id = :gblId
		];
		r.add(grantBudgetLine);
		//CBGMConst.BALANCE_FUND_SCENARIO_NAME
		r.addAll([
				SELECT Id,Name,cb5__CBVariable1__c, (SELECT cb5__CBPeriod__c, cb5__Value__c FROM cb5__CBAmounts__r ORDER BY cb5__CBPeriod__r.cb5__Start__c)
				FROM cb5__CBBudgetLine__c
				WHERE cb5__CBVariable1__c IN:new Set<String>(availableFundIds) AND cb5__CBBudgetYear__c = :grantBudgetLine.cb5__CBBudgetYear__c
				AND cb5__CBScenario__r.Name = :CBGMConst.BALANCE_FUND_SCENARIO_NAME
				ORDER BY Name
		]);
		return r;

	}


}