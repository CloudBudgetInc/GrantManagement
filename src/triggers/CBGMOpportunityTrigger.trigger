/**
 * Created by Alex JR on 11/8/2023.
 */

trigger CBGMOpportunityTrigger on Opportunity (after insert, after update, before delete) {

	Set<Id> oppIdSet = new Set<Id>();
	List<Opportunity> opportunities = Trigger.isDelete ? Trigger.old : Trigger.new;
	for (Opportunity opp : opportunities) oppIdSet.add(opp.Id);
	CBGMOpportunityDomain.populateOpportunityMap(oppIdSet);
	if (CBGMOpportunityDomain.ignoreOpportunities) return; // if opportunity type is not grant nor fund

	if (Trigger.isInsert || Trigger.isUpdate) {
		for (Opportunity opp : Trigger.new) {
			CBGMOpportunityDomain.updateCBMapping(opp.Id);
			CBGMOpportunityDomain.updateBudgetLines(opp.Id);
			CBGMOpportunityDomain.updateContractValues(opp.Id);
			CBGMOpportunityDomain.updateOpportunityWarnings(opp.Id);
		}
	}

	if (Trigger.isBefore && Trigger.isDelete) {
		CBGMOpportunityDomain.deleteAllRelatedToOpportunityData(oppIdSet);
	}

}