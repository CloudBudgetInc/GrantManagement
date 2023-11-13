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


public with sharing class CBGMGrantPageController {

	private static final String GRANT_PLAN_SCENARIO_NAME = 'Grant Plan';
	private static final String DEFAULT_GRANT_ACCOUNT_NAME = 'Grant';

	@AuraEnabled
	public static Map<String, Map<String, String>> getAnalyticsServer(String oppId) {
		Map<String, Map<String, String>> r = new Map<String, Map<String, String>>();

		Map<String, String> bYears = new Map<String, String>();
		for (cb5__CBBudgetYear__c budgetYear : [SELECT Id, Name FROM cb5__CBBudgetYear__c ORDER BY Name]) {
			bYears.put(budgetYear.Id, budgetYear.Name);
		}
		r.put('budgetYearSO', bYears);

		Map<String, String> funds = new Map<String, String>();
		String destination = [SELECT Destination__c FROM Opportunity WHERE Id = :oppId][0].Destination__c;
		List<String> destSet = new List<String>(destination.split(','));

		Map<String, String> fundSO = new Map<String, String>();
		Set<String> fundOppIds = new Set<String>();
		for (Opportunity fund : [SELECT Id FROM Opportunity WHERE Destination__c INCLUDES (:destination)]) fundOppIds.add(fund.Id);
		for (cb5__CBVariable1__c fund : [SELECT Id, Name FROM cb5__CBVariable1__c WHERE cb5__ExtId__c IN:fundOppIds ORDER BY Name]) {
			fundSO.put(fund.Id, fund.Name);
		}
		r.put('fundSO', fundSO);

		return r;
	}

	/**
	 * 
	 *
	 * @param oppId grant type opportunity
	 *
	 * @return
	 */
	@AuraEnabled
	public static List<cb5__CBBudgetLine__c> getGrantBudgetLinesServer(String oppId) {
		return [
				SELECT Id, Name, cb5__CBVariable1__c, cb5__CBBudgetYear__r.Name, cb5__CBBudgetYear__c, cb5__Value__c, (
						SELECT Id, cb5__Value__c, cb5__CBPeriod__c, cb5__CBPeriod__r.cb5__CBBudgetYear__r.Name, cb5__CBPeriod__r.Name
						FROM cb5__CBAmounts__r
						ORDER BY cb5__CBPeriod__r.cb5__Start__c
				)
				FROM cb5__CBBudgetLine__c
				WHERE cb5__CBScenario__r.Name = :GRANT_PLAN_SCENARIO_NAME
				AND cb5__CBVariable2__r.cb5__ExtId__c = :oppId
				ORDER BY cb5__CBBudgetYear__r.Name
		];
	}

	@AuraEnabled
	public static void saveGrantAmountServer(cb5__CBAmount__c amount) {
		update amount;
	}

	@AuraEnabled
	public static void saveBudgetLineServer(cb5__CBBudgetLine__c budgetLine) {
		update budgetLine;
	}

	@AuraEnabled
	public static void addBudgetLineServer(String oppId, String selectedBYId) {
		String grantId = [SELECT Id FROM cb5__CBVariable2__c WHERE cb5__ExtId__c = :oppId][0].Id;
		String accId = [SELECT Id FROM cb5__CBAccount__c WHERE Name = :DEFAULT_GRANT_ACCOUNT_NAME][0].Id;
		String scenarioId = [SELECT Id FROM cb5__CBScenario__c WHERE Name = :GRANT_PLAN_SCENARIO_NAME][0].Id;

		cb5__CBBudgetLine__c budgetLine = new cb5__CBBudgetLine__c(Name = 'New', cb5__CBVariable2__c = grantId, cb5__CBAccount__c = accId,
				cb5__CBBudgetYear__c = selectedBYId, cb5__CBScenario__c = scenarioId);
		insert budgetLine;

		List<cb5__CBAmount__c> amounts = new List<cb5__CBAmount__c>();
		for (cb5__CBPeriod__c period : [SELECT Id FROM cb5__CBPeriod__c WHERE cb5__CBBudgetYear__c = :selectedBYId]) {
			amounts.add(new cb5__CBAmount__c(cb5__CBBudgetLine__c = budgetLine.Id, cb5__CBPeriod__c = period.Id, cb5__Value__c = 0));
		}
		insert amounts;
	}

}