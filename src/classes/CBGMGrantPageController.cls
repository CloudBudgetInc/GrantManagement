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

	@AuraEnabled
	public static String swapContractToOpportunityServer(String contractOppId) {
		Id someId = (Id) contractOppId;
		Schema.SObjectType sObjectType = someId.getSObjectType();
		String sObjectName = sObjectType.getDescribe().getName();
		if (sObjectName == 'Contract') {
			return [SELECT Opportunity__c FROM Contract WHERE Id = :contractOppId].Opportunity__c;
		}
		return contractOppId;
	}

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
		Map<String, String> fundSO = new Map<String, String>();
		r.put('fundSO', fundSO);

		if (!String.isEmpty(destination)) {
			List<String> destSet = new List<String>(destination.split(';'));
			Set<String> fundOppIds = new Set<String>();
			for (Opportunity fund : [SELECT Id FROM Opportunity WHERE RecordType.Name = 'Fund' AND Destination__c INCLUDES (:destination)]) fundOppIds.add(fund.Id);
			for (cb5__CBVariable1__c fund : [SELECT Id, Name FROM cb5__CBVariable1__c WHERE cb5__ExtId__c IN:fundOppIds ORDER BY Name]) {
				fundSO.put(fund.Id, fund.Name);
			}
		}
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
				SELECT Id,Name,cb5__CBSubAccountName__c,cb5__CBDivision__r.Name,
						cb5__CBVariable1__c,cb5__CBVariable2__c,cb5__CBVariable3__c,cb5__CBVariable4__c,cb5__CBVariable5__c,
						cb5__CBVariable1__r.Name,cb5__CBVariable2__r.Name,cb5__CBVariable3__r.Name,cb5__CBVariable4__r.Name,cb5__CBVariable5__r.Name,
						cb5__CBBudgetYear__r.Name,cb5__CBBudgetYear__c,cb5__Value__c,cb5__Lock__c,cb5__Description__c, (
						SELECT Id, cb5__Value__c, cb5__CBPeriod__c, cb5__CBPeriod__r.cb5__CBBudgetYear__r.Name, cb5__CBPeriod__r.Name
						FROM cb5__CBAmounts__r
						ORDER BY cb5__CBPeriod__r.cb5__Start__c
				)
				FROM cb5__CBBudgetLine__c
				WHERE cb5__CBScenario__r.Name = :CBGMConst.BASE_SCENARIO_NAME
				AND cb5__CBVariable2__r.cb5__ExtId__c = :oppId
				ORDER BY cb5__CBBudgetYear__r.Name, CreatedDate
		];
	}

	@AuraEnabled
	public static void saveGrantAmountServer(cb5__CBAmount__c amount, String oppId) {
		update amount;
	}

	@AuraEnabled
	public static void recalculateOpportunityAmountServer(String oppId) {
		CBGMOpportunityDomain.recalculateTotalAmounts(oppId);
	}


	@AuraEnabled
	public static void saveGrantBudgetLineServer(cb5__CBBudgetLine__c budgetLine) {
		Set<String> var1Ids = new Set<String>();
		if (budgetLine.Id != null) {
			String oldVar1 = [SELECT cb5__CBVariable1__c FROM cb5__CBBudgetLine__c WHERE Id = :budgetLine.Id].cb5__CBVariable1__c;
			if (oldVar1 != null) var1Ids.add(oldVar1);
		}
		if (budgetLine.cb5__CBVariable1__c != null) var1Ids.add(budgetLine.cb5__CBVariable1__c);
		update budgetLine;

		if (var1Ids.size() > 0) {
			CBGMFundBalanceService.recalculateListOfVar1Balances(new List<String> (var1Ids));
		}
	}

	@AuraEnabled
	public static void addBudgetLineServer(String oppId, String selectedBYId) {
		String grantId = [SELECT Id FROM cb5__CBVariable2__c WHERE cb5__ExtId__c = :oppId][0].Id;
		String accId = [SELECT Id FROM cb5__CBAccount__c WHERE Name = :CBGMConst.DEFAULT_GRANT_ACCOUNT_NAME][0].Id;
		String scenarioId = [SELECT Id FROM cb5__CBScenario__c WHERE Name = :CBGMConst.BASE_SCENARIO_NAME][0].Id;

		cb5__CBBudgetLine__c budgetLine = new cb5__CBBudgetLine__c(Name = 'New', cb5__CBVariable2__c = grantId, cb5__CBAccount__c = accId,
				cb5__CBBudgetYear__c = selectedBYId, cb5__CBScenario__c = scenarioId);
		insert budgetLine;

		List<cb5__CBAmount__c> amounts = new List<cb5__CBAmount__c>();
		for (cb5__CBPeriod__c period : [SELECT Id FROM cb5__CBPeriod__c WHERE cb5__CBBudgetYear__c = :selectedBYId]) {
			amounts.add(new cb5__CBAmount__c(cb5__CBBudgetLine__c = budgetLine.Id, cb5__CBPeriod__c = period.Id, cb5__Value__c = 0));
		}
		insert amounts;
	}

	@AuraEnabled
	public static Boolean isManagerServer() {
		User user = [SELECT Profile.Name FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1][0];
		if (user.Profile.Name.equals(CBGMConst.NEEDED_PROFILE_NAME)) return true;
		for (PermissionSetAssignment psa : [SELECT PermissionSet.Name FROM PermissionSetAssignment WHERE AssigneeId = :user.Id]) {
			if (psa.PermissionSet.Name.equals(CBGMConst.NEEDED_PERMISSION_SET_NAME)) return true;
		}
		return false;
	}

	@AuraEnabled
	public static String getCBGrantIdFromOppGrantIdServer(String oppId) {
		try {
			return [SELECT Id FROM cb5__CBVariable2__c WHERE cb5__ExtId__c = :oppId LIMIT 1][0].Id;
		} catch (Exception e) {
			return null;
		}
	}

	@AuraEnabled
	public static cb5__CBOrgVariable__c getOrgVariableServer() {
		return [SELECT cb5gm__GMGrantGrouping__c FROM cb5__CBOrgVariable__c LIMIT 1][0];
	}


}