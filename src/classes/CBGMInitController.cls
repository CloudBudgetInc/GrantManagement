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


global with sharing class CBGMInitController {

	global static void generateInitialData() {
		List<cb5__CBScenario__c> balances = [SELECT ID FROM cb5__CBScenario__c WHERE Name = :CBGMConst.BALANCE_FUND_SCENARIO_NAME LIMIT 1];
		if (balances.size() == 0) {
			generateScenarios();
		}

		List<cb5__CBOrgVariable__c> vars = [SELECT ID FROM cb5__CBOrgVariable__c LIMIT 1];
		if (vars.size() == 0) {
			cb5__CBOrgVariable__c orgVariable = new cb5__CBOrgVariable__c();
			insert orgVariable;
		}

		generateAccounts();
		generatePeriods();
	}

	private static void generateScenarios() {
		List<cb5__CBScenario__c> scenarios = new List<cb5__CBScenario__c>();
		List<String> scenarioNames = new List<String>{
				CBGMConst.BALANCE_FUND_SCENARIO_NAME,
				CBGMConst.BASE_SCENARIO_NAME
		};
		for (String s : scenarioNames) scenarios.add(new cb5__CBScenario__c(Name = s));
		insert scenarios;
	}

	private static void generateAccounts() {
		List<cb5__CBAccountType__c> types = [SELECT Id FROM cb5__CBAccountType__c WHERE Name LIKE '%Expense%' LIMIT 1];
		cb5__CBAccountType__c accType;
		if (types.size() > 0) {
			accType = types[0];
		} else {
			accType = new cb5__CBAccountType__c(Name = 'Expenses', cb5__Sign__c = '+');
			insert accType;
		}

		List<cb5__CBSubAccount__c> subTypes = new List<cb5__CBSubAccount__c>();
		cb5__CBSubAccount__c fundSubAccType = new cb5__CBSubAccount__c(Name = 'Fund');
		cb5__CBSubAccount__c grantSubAccType = new cb5__CBSubAccount__c(Name = 'Grant');
		subTypes.add(fundSubAccType);
		subTypes.add(grantSubAccType);
		insert subTypes;

		List<cb5__CBAccount__c> accounts = new List<cb5__CBAccount__c>();
		cb5__CBAccount__c fundAccount = new cb5__CBAccount__c(Name = CBGMConst.DEFAULT_FUNDING_ACCOUNT_NAME, cb5__CBAccountType__c = accType.Id, cb5__CBSubAccount__c = fundSubAccType.Id);
		cb5__CBAccount__c grantAccount = new cb5__CBAccount__c(Name = CBGMConst.DEFAULT_GRANT_ACCOUNT_NAME, cb5__CBAccountType__c = accType.Id, cb5__CBSubAccount__c = grantSubAccType.Id);
		accounts.add(fundAccount);
		accounts.add(grantAccount);
		insert accounts;
	}

	private static void generatePeriods() {
		List<cb5__CBBudgetYear__c> budgetYears = [SELECT Id FROM cb5__CBbudgetYear__c LIMIT 1];
		if (budgetYears.size() > 0) return;

		cb5__CBBudgetYear__c budgetYear = new cb5__CBBudgetYear__c(Name = '2025', cb5__Start__c = Date.newInstance(2025, 1, 1));
		insert budgetYear;

		List<cb5__CBPeriod__c> periods = new List<cb5__CBPeriod__c>();
		for (Integer i = 1; i <= 12; i++) {
			periods.add(new cb5__CBPeriod__c(Name = 'M' + i, cb5__Start__c = Date.newInstance(2025, i, 1), cb5__End__c = Date.newInstance(2025, i, 25), cb5__CBBudgetYear__c = budgetYear.Id));
		}
		insert periods;
	}

}