/**
 * Created by Alex JR on 12/1/2023.
 */

trigger CBGMInvoiceTrigger on cb5__CBInvoice__c (after insert, after update) {

	if (CBGMConst.invoiceTriggerDone) return ;
	if (Trigger.isAfter) {
		CBGMConst.invoiceTriggerDone = true;
		Set<String> var1Ids = new Set<String>();
		Set<String> var2Ids = new Set<String>();
		List<cb5__CBInvoice__c> invoices = Trigger.new;
		List<String> invoicesIdsToUpsert = new List<String>();
		for (cb5__CBInvoice__c inv : invoices) {
			if (inv.cb5__CBVariable1__c != null) var1Ids.add(inv.cb5__CBVariable1__c);
			if (inv.cb5__CBVariable2__c != null) var2Ids.add(inv.cb5__CBVariable2__c);
			invoicesIdsToUpsert.add(inv.Id);
		}
		Map<String, String> varMap = new Map<String, String>();
		if (var1Ids.size() > 0) {
			for (cb5__CBVariable1__c var1 : [SELECT Id, cb5__ExtId__c FROM cb5__CBVariable1__c WHERE ID IN:var1Ids]) varMap.put(var1.Id, var1.cb5__ExtId__c);
		}
		if (var2Ids.size() > 0) {
			for (cb5__CBVariable2__c var2 : [SELECT Id, cb5__ExtId__c FROM cb5__CBVariable2__c WHERE ID IN:var2Ids]) varMap.put(var2.Id, var2.cb5__ExtId__c);
		}
		if (varMap.size() == 0) return ;

		invoices = [SELECT Id, cb5__CBVariable1__c, cb5__CBVariable2__c FROM cb5__CBInvoice__c WHERE Id IN:invoicesIdsToUpsert];
		for (cb5__CBInvoice__c inv : invoices) {
			if (inv.cb5__CBVariable1__c != null) inv.Opportunity__c = varMap.get(inv.cb5__CBVariable1__c);
			if (inv.cb5__CBVariable2__c != null) inv.Opportunity__c = varMap.get(inv.cb5__CBVariable2__c);
		}
		update invoices;
	}

}