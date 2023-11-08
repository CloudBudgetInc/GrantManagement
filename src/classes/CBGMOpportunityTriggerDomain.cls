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


public with sharing class CBGMOpportunityTriggerDomain {

	public static void updateCBAnalytics(Id oppId) {
		Opportunity opp = [SELECT Id, Name, RecordType.Name FROM Opportunity WHERE id = :oppId][0];
		if (opp.RecordType.Name == 'Fund') {
			List<cb5__CBVariable1__c> variable1s = [SELECT Id FROM cb5__CBVariable1__c WHERE cb5__ExtId__c = :opp.Id];
			System.debug('opp.Id = ' + opp.Id + ' Name = ' + opp.Name);
			System.debug('Variables = ' + variable1s);
			if (variable1s.size() == 0) {
				insert new cb5__CBVariable1__c(Name = opp.Name, cb5__ExtId__c = opp.Id);
			} else {
				cb5__CBVariable1__c var1 = variable1s[0];
				var1.Name = opp.Name;
				update var1;
			}
		}
		if (opp.RecordType.Name == 'Grant') {
			List<cb5__CBVariable2__c> variable2s = [SELECT Id FROM cb5__CBVariable2__c WHERE cb5__ExtId__c = :opp.Id];
			if (variable2s.size() == 0) {
				insert new cb5__CBVariable2__c(Name = opp.Name, cb5__ExtId__c = opp.Id);
			} else {
				cb5__CBVariable2__c var2 = variable2s[0];
				var2.Name = opp.Name;
				update var2;
			}
		}
	}

}