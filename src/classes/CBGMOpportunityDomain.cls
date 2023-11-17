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

	public static void recalculateTotalAmounts(String oppId) {

		Opportunity opportunity = [SELECT Id, RecordType.Name FROM Opportunity WHERE Id = :oppId];

		if (opportunity.RecordType.Name == 'Fund') {
			List<cb5__CBVariable1__c> vars1 = [SELECT Id FROM cb5__CBVariable1__c WHERE cb5__ExtId__c = :oppId];
			if (vars1.size() == 0) return ;
			cb5__CBVariable1__c var1 = vars1[0];
			System.debug('Is Fund');
			List<AggregateResult> ags = [
					SELECT SUM(cb5__Value__c) cb5__Value__c
					FROM cb5__CBAmount__c
					WHERE cb5__CBBudgetLine__r.cb5__CBScenario__r.Name = :CBGMConst.COMMITTED_FUND_SCENARIO_NAME
					AND cb5__CBBudgetLine__r.cb5__CBVariable1__c = :var1.Id
			];
			System.debug('AGS =' + ags);
			if (ags.size() > 0) {
				opportunity.AmountCommitted__c = (Decimal) ags[0].get('cb5__Value__c');
				update opportunity;
			}
		}

		if (opportunity.RecordType.Name == 'Grant') {
			System.debug('Is GRANT');
			List<cb5__CBVariable2__c> vars2 = [SELECT Id FROM cb5__CBVariable2__c WHERE cb5__ExtId__c = :oppId];
			if (vars2.size() == 0) return ;
			cb5__CBVariable2__c var2 = vars2[0];
			List<AggregateResult> ags = [
					SELECT SUM(cb5__Value__c) cb5__Value__c
					FROM cb5__CBAmount__c
					WHERE cb5__CBBudgetLine__r.cb5__CBScenario__r.Name = :CBGMConst.GRANT_PLAN_SCENARIO_NAME
					AND cb5__CBBudgetLine__r.cb5__CBVariable2__c = :var2.Id
			];
			System.debug('AGS =' + ags);
			if (ags.size() > 0) {
				opportunity.Amount = (Decimal) ags[0].get('cb5__Value__c');
				update opportunity;
			}
		}
	}

}