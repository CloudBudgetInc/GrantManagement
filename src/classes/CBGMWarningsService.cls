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


public with sharing class CBGMWarningsService {

	static List<cb5__CBLog__c> logsToInsert = new List<cb5__CBLog__c>();
	static Set<String> oppIds = new Set<String>();

	static Map<String, String> oppBalanceShortfallMap {
		get {
			if (oppBalanceShortfallMap == null) {
				oppBalanceShortfallMap = new Map<String, String>();
				for (cb5__CBAmount__c a : [
						SELECT Id, cb5__CBPeriod__r.Name, cb5__CBBudgetLine__r.cb5__CBVariable1__r.cb5__ExtId__c, cb5__Value__c
						FROM cb5__CBAmount__c
						WHERE cb5__Value__c < 0
						AND cb5__CBBudgetLine__r.cb5__CBScenario__r.Name = :CBGMConst.BALANCE_FUND_SCENARIO_NAME
						AND cb5__CBBudgetLine__r.cb5__CBVariable1__r.cb5__ExtId__c IN:oppIds
						ORDER BY cb5__CBPeriod__r.cb5__Start__c
				]) {
					String message = 'The budget shortfall in ' + a.cb5__CBPeriod__r.Name + ' is $' + (a.cb5__Value__c * -1);
					oppBalanceShortfallMap.put(a.cb5__CBBudgetLine__r.cb5__CBVariable1__r.cb5__ExtId__c, message);
				}
			}
			return oppBalanceShortfallMap;
		}
		set;
	}

	public static void updateWarnings(List<String> opportunityIds) {
		if (opportunityIds == null) {
			for (Opportunity opp : [SELECT Id FROM Opportunity WHERE RecordType.Name = 'Fund' OR RecordType.Name = 'Grant']) {
				oppIds.add(opp.Id);
			}
		} else {
			oppIds = new Set<String> (opportunityIds);
		}
		for (String oppId : oppIds) {
			populateShortfallOpportunityWarnings(oppId);
		}
		deleteOldLogs();
		insert logsToInsert;
	}

	private static void deleteOldLogs() {
		delete [SELECT Id FROM cb5__CBLog__c WHERE Opportunity__c IN:oppIds];
	}

	private static void populateShortfallOpportunityWarnings(String oppId) {
		String logMessage = oppBalanceShortfallMap.get(oppId);
		if (logMessage == null) return ;
		logsToInsert.add(new cb5__CBLog__c(cb5__Type__c = 'Warning', Opportunity__c = oppId, cb5__Description__c = logMessage));
	}

}