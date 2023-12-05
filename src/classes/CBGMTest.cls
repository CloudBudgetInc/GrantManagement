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

@isTest
public with sharing class CBGMTest {

	@TestSetup
	public static void generateInitialData() {
		/*cb5__CBOrgVariable__c orgVariable = new cb5__CBOrgVariable__c();
		insert orgVariable;

		cb5__CBBudgetYear__c budgetYear = new cb5__CBBudgetYear__c(Name = '2024', cb5__Start__c = Date.newInstance(2024, 1, 1));
		insert budgetYear;

		List<cb5__CBPeriod__c> periods = new List<cb5__CBPeriod__c>();
		for (Integer i = 1; i <= 12; i++) {
			periods.add(new cb5__CBPeriod__c(Name = 'M' + i, cb5__Start__c = Date.newInstance(2024, i, 1), cb5__End__c = Date.newInstance(2024, i, 25), cb5__CBBudgetYear__c = budgetYear.Id));
		}
		insert periods;

		cb5__CBAccountType__c accType = new cb5__CBAccountType__c(Name = 'Expenses', cb5__Sign__c = '+');
		insert accType;

		cb5__CBSubAccount__c subAccType = new cb5__CBSubAccount__c(Name = 'Other');
		insert subAccType;

		List<cb5__CBAccount__c> accounts = new List<cb5__CBAccount__c>();
		accounts.add(new cb5__CBAccount__c(Name = CBGMConst.DEFAULT_FUNDING_ACCOUNT_NAME, cb5__CBAccountType__c = accType.Id, cb5__CBSubAccount__c = subAccType.Id));
		accounts.add(new cb5__CBAccount__c(Name = CBGMConst.DEFAULT_GRANT_ACCOUNT_NAME, cb5__CBAccountType__c = accType.Id, cb5__CBSubAccount__c = subAccType.Id));
		insert accounts;

		List<cb5__CBScenario__c> scenarios = new List<cb5__CBScenario__c>();
		scenarios.add(new cb5__CBScenario__c(Name = CBGMConst.COMMITTED_FUND_SCENARIO_NAME));
		scenarios.add(new cb5__CBScenario__c(Name = CBGMConst.DEFAULT_FUNDING_ACCOUNT_NAME));
		scenarios.add(new cb5__CBScenario__c(Name = CBGMConst.BALANCE_FUND_SCENARIO_NAME));
		scenarios.add(new cb5__CBScenario__c(Name = CBGMConst.GRANT_PLAN_SCENARIO_NAME));
		insert scenarios;*/
	}

	@isTest
	public static void testFundsAndGrants() {
		CBGMInitController.generateInitialData();

		cb5__CBBudgetYear__c budgetYear = [SELECT Id, Name FROM cb5__CBBudgetYear__c LIMIT 1][0];

		Id fundRecordTypeId = Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get('Fund').getRecordTypeId();
		Id grantRecordTypeId = Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get('Grant').getRecordTypeId();
		List<Opportunity> opps = new List<Opportunity>();
		Opportunity fund = new Opportunity(Name = 'Fund', RecordTypeId = fundRecordTypeId, CloseDate = Date.newInstance(2024, 5, 5), StageName = 'Value Proposition');
		opps.add(fund);
		Opportunity grant = new Opportunity(Name = 'Grant', RecordTypeId = grantRecordTypeId, CloseDate = Date.newInstance(2024, 5, 5), StageName = 'Program Monitoring');
		opps.add(grant);
		insert opps;

		CBGMFundPageController.getAnalyticsServer();
		CBGMFundPageController.generateFundBudgetLinesServer(fund.Id);
		List<cb5__CBBudgetLine__c> fundBudgetLines = CBGMFundPageController.getFundBudgetLinesServer(fund.Id);
		cb5__CBAmount__c amount = fundBudgetLines[0].cb5__CBAmounts__r[0];
		CBGMFundPageController.saveFundAmountServer(amount);


		String var1FundId = [SELECT Id FROM cb5__CBVariable1__c][0].Id;
		CBGMGrantPageController.addBudgetLineServer(grant.Id, budgetYear.Id);
		List<cb5__CBBudgetLine__c> grantBudgetLines = CBGMGrantPageController.getGrantBudgetLinesServer(grant.Id);
		grantBudgetLines[0].cb5__CBVariable1__c = var1FundId;
		update grantBudgetLines;
		CBGMGrantPageController.saveGrantBudgetLineServer(grantBudgetLines[0]);
		CBGMGrantPageController.getAnalyticsServer(grant.Id);

		CBGMFundPageController.updateOpportunityByTriggerServer(fund.Id);
		CBGMFundPageController.getAllocationGrantsServer(fund.Id);
		CBGMFundPageController.recalculateFundBalanceBudgetServer(fund.Id);

		CBGMLockBudgetAction.cg();
		CBGMUnlockBudgetAction.cg();

		//CBGMFundBalanceBatch ba = new CBGMFundBalanceBatch();
		//Id jobId = Database.executeBatch(ba, 5);

		insert new cb5__CBInvoice__c(Name = 'test', cb5__CBVariable1__c = var1FundId);

		CBGMFundBalanceProcess process = new CBGMFundBalanceProcess();
		process.runProcess(null, null);


	}


}