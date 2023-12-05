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


public with sharing class CBGMFundBalanceService {

	private static String balanceScenarioId {
		get {
			if (balanceScenarioId == null) {
				balanceScenarioId = [SELECT Id FROM cb5__CBScenario__c WHERE Name = :CBGMConst.BALANCE_FUND_SCENARIO_NAME][0].Id;
			}
			return balanceScenarioId;
		}
		set;
	}

	private static String balanceAccountId {
		get {
			if (balanceAccountId == null) {
				balanceAccountId = [SELECT Id FROM cb5__CBAccount__c WHERE Name = :CBGMConst.DEFAULT_FUNDING_ACCOUNT_NAME][0].Id;
			}
			return balanceAccountId;
		}
		set;
	}

	private static Map<String, String> fundIdNameMap {
		get {
			if (fundIdNameMap == null) {
				fundIdNameMap = new Map<String, String>();
				for (cb5__CBVariable1__c variable1 : [SELECT Id,Name FROM cb5__CBVariable1__c]) fundIdNameMap.put(variable1.Id, variable1.Name);
			}
			return fundIdNameMap;
		}
		set;
	}

	/**
	 * Decorator for the main method
	 *
	 * @param var1Ids CBVar1 Ids
	 */
	public static void recalculateListOfVar1Balances(List<String> var1Ids) {
		if (var1Ids == null || var1Ids.size() == 0) return;
		List<String> oppIds = new List<String>();
		for (cb5__CBVariable1__c var1 : [SELECT cb5__ExtId__c FROM cb5__CBVariable1__c WHERE Id IN:new Set<String> (var1Ids)]) {
			oppIds.add(var1.cb5__ExtId__c);
		}
		recalculateListOfFundBalances(oppIds);
	}

	/**
	 *
	 * @param oppIds fund opportunity ids
	 */
	public static void recalculateListOfFundBalances(List<String> oppIds) {
		List<cb5__CBVariable1__c> funds = [SELECT Id,Name FROM cb5__CBVariable1__c WHERE cb5__ExtId__c IN:new Set<String>(oppIds)];
		Set<String> fundIds = new Set<String>();
		for (cb5__CBVariable1__c fund : funds) fundIds.add(fund.Id);
		deleteOldBalanceBudgetLines(fundIds, balanceScenarioId);

		Map<String, BLWrapper> fundWrappers = getFundBudgetWrappers(fundIds);
		//System.debug('///////// FUND /////////');
		//for (BLWrapper fw : fundWrappers.values()) fw.debug();
		//System.debug('///////// FUND /////////');
		Map<String, BLWrapper> grantWrappers = getGrantBudgetWrappers(fundIds);
		//System.debug('///////// GRANT /////////');
		//for (BLWrapper gw : grantWrappers.values()) gw.debug();
		//System.debug('///////// GRANT /////////');

		List<BLWrapper> balanceWrappers = getBalanceWrappers(fundWrappers, grantWrappers, fundIds);
		//System.debug('///////// RESULT /////////');
		for (BLWrapper wrap : balanceWrappers) {
			wrap.debug();
		}
		new BLWrapper().insertBudgetLines(balanceWrappers);

	}

	public static List<BLWrapper> getBalanceWrappers(Map<String, BLWrapper> fundWrappers, Map<String, BLWrapper> grantWrappers, Set<String> fundIds) {
		List<BLWrapper> result = new List<CBGMFundBalanceService.BLWrapper>();
		List<cb5__CBBudgetYear__c> budgetYears = [SELECT Id, Name, (SELECT Id FROM cb5__CBPeriods__r ORDER BY cb5__Start__c) FROM cb5__CBBudgetYear__c ORDER BY Name];
		for (String fundId : fundIds) {
			BLWrapper fundWrapper = fundWrappers.get(fundId);
			BLWrapper grantWrapper = grantWrappers.get(fundId);
			List<BLWrapper> singleFundBalanceWrappers = getSingleFondBalanceWrappers(fundWrapper, grantWrapper, budgetYears, fundId);
			result.addAll(singleFundBalanceWrappers);
		}
		return result;
	}

	private static List<BLWrapper> getSingleFondBalanceWrappers(BLWrapper fundWrapper, BLWrapper grantWrapper, List<cb5__CBBudgetYear__c> budgetYears, String fundId) {
		Decimal balanceValue = 0;
		List<BLWrapper> result = new List<BLWrapper>();
		for (cb5__CBBudgetYear__c budgetYear : budgetYears) {
			if (fundWrapper == null) continue;
			Map<String, Decimal> byFundAmountsMap = fundWrapper.amountsMap.get(budgetYear.Id);
			if (byFundAmountsMap == null) continue; // this year does not need balances
			BLWrapper balanceWrapper = new BLWrapper();
			result.add(balanceWrapper);
			balanceWrapper.bl.cb5__CBBudgetYear__c = budgetYear.Id;
			balanceWrapper.bl.cb5__CBAccount__c = balanceAccountId;
			balanceWrapper.bl.cb5__CBScenario__c = balanceScenarioId;
			balanceWrapper.bl.cb5__CBVariable1__c = fundId;
			balanceWrapper.bl.Name = fundIdNameMap.get(fundId);

			Map<String, Decimal> byGrantAmountsMap = grantWrapper == null ? new Map<String, Decimal>() : grantWrapper.amountsMap.get(budgetYear.Id);

			for (cb5__CBPeriod__c period : budgetYear.cb5__CBPeriods__r) {
				String periodId = period.Id;
				Decimal fundAmount = byFundAmountsMap.get(periodId);
				fundAmount = fundAmount == null ? 0 : fundAmount;
				Decimal grantAmount = byGrantAmountsMap == null || byGrantAmountsMap.get(periodId) == null ? 0 : byGrantAmountsMap.get(periodId);
				balanceValue = balanceValue + fundAmount - grantAmount;
				balanceWrapper.amounts.add(new cb5__CBAmount__c(cb5__CBPeriod__c = periodId, cb5__Value__c = balanceValue));
			}
		}
		return result;
	}

	/**
	 * Key is fund Id
	 * fundIds (CBVariable1 type)
	 */
	public static Map<String, BLWrapper> getFundBudgetWrappers(Set<String> fundIds) {
		Map<String, BLWrapper> result = new Map<String, BLWrapper>();
		for (cb5__CBBudgetLine__c bl : [
				SELECT Id, cb5__CBVariable1__c, cb5__CBBudgetYear__c, (SELECT cb5__CBPeriod__c, cb5__Value__c FROM cb5__CBAmounts__r)
				FROM cb5__CBBudgetLine__c
				WHERE cb5__CBVariable1__c IN:fundIds
				AND cb5__CBScenario__r.Name = :CBGMConst.BASE_SCENARIO_NAME
				AND cb5__CBSubAccountName__c = 'Fund'
				ORDER BY cb5__CBVariable1__r.Name, cb5__CBBudgetYear__r.cb5__Start__c
		]) {
			BLWrapper wrapper = result.get(bl.cb5__CBVariable1__c);
			if (wrapper == null) {
				wrapper = new BLWrapper();
				result.put(bl.cb5__CBVariable1__c, wrapper);
			}
			Map<String, Decimal> amountMap = new Map<String, Decimal>();
			for (cb5__CBAmount__c a : bl.cb5__CBAmounts__r) amountMap.put(a.cb5__CBPeriod__c, a.cb5__Value__c);
			wrapper.amountsMap.put(bl.cb5__CBBudgetYear__c, amountMap);
		}
		return result;
	}

	public static Map<String, BLWrapper> getGrantBudgetWrappers(Set<String> fundIds) {
		Map<String, BLWrapper> result = new Map<String, BLWrapper>();
		for (AggregateResult ar : [
				SELECT SUM(cb5__Value__c) cb5__Value__c, cb5__CBBudgetLine__r.cb5__CBVariable1__c cb5__CBVariable1__c,
						cb5__CBBudgetLine__r.cb5__CBBudgetYear__c cb5__CBBudgetYear__c, cb5__CBPeriod__c
				FROM cb5__CBAmount__c
				WHERE cb5__CBBudgetLine__r.cb5__CBVariable1__c IN:fundIds AND cb5__CBBudgetLine__r.cb5__CBScenario__r.Name = :CBGMConst.BASE_SCENARIO_NAME
				AND cb5__CBBudgetLine__r.cb5__CBSubAccountName__c != 'Fund'
				GROUP BY cb5__CBBudgetLine__r.cb5__CBVariable1__c, cb5__CBBudgetLine__r.cb5__CBBudgetYear__c, cb5__CBPeriod__c
		]) {
			String CBVariable1 = (String) ar.get('cb5__CBVariable1__c');
			String CBBudgetYear = (String) ar.get('cb5__CBBudgetYear__c');
			String CBPeriod = (String) ar.get('cb5__CBPeriod__c');
			Decimal Value = (Decimal) ar.get('cb5__Value__c');

			BLWrapper wrapper = result.get(CBVariable1);
			if (wrapper == null) {
				wrapper = new BLWrapper();
				result.put(CBVariable1, wrapper);
			}
			Map<String, Decimal> amountMap = wrapper.amountsMap.get(CBBudgetYear);
			if (amountMap == null) {
				amountMap = new Map<String, Decimal>();
				wrapper.amountsMap.put(CBBudgetYear, amountMap);
			}
			amountMap.put(CBPeriod, Value);
		}
		return result;
	}

	public static void deleteOldBalanceBudgetLines(Set<String> fundIds, String balanceScenarioId) {
		delete [SELECT Id FROM cb5__CBBudgetLine__c WHERE cb5__CBVariable1__c IN:fundIds AND cb5__CBScenario__c = :balanceScenarioId];
	}

	public class BLWrapper {
		public cb5__CBBudgetLine__c bl = new cb5__CBBudgetLine__c();
		public List<cb5__CBAmount__c> amounts = new List<cb5__CBAmount__c>();
		/**
		 * First key is byId, second key is periodId
		 */
		public Map<String, Map<String, Decimal>> amountsMap = new Map<String, Map<String, Decimal>>();

		public void insertBudgetLines(List<BLWrapper> wrappers) {
			List<cb5__CBBudgetLine__c> bLines = new List<cb5__CBBudgetLine__c>();
			for (BLWrapper w : wrappers) {
				System.debug(w.bl);
				bLines.add(w.bl);
			}
			insert bLines;

			List<cb5__CBAmount__c> ams = new List<cb5__CBAmount__c>();
			for (BLWrapper w : wrappers) {
				for (cb5__CBAmount__c a : w.amounts) {
					a.cb5__CBBudgetLine__c = w.bl.Id;
					ams.add(a);
				}
			}
			insert ams;
		}


		public void debug() {
			if (bl.cb5__CBBudgetYear__c != null) {
				System.debug('BL: ' + bl);
			}
			if (amounts.size() > 0) {
				for (cb5__CBAmount__c a : amounts) {
					System.debug(a);
				}
			}
			if (amountsMap.keySet().size() > 0) {
				for (String key : amountsMap.keySet()) {
					System.debug('KEY = ' + key);
					System.debug('AM = ' + amountsMap.get(key));
				}
			}
		}
	}

}