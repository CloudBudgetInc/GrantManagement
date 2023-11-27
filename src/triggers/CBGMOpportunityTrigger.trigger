/**
 * Created by Alex JR on 11/8/2023.
 */

trigger CBGMOpportunityTrigger on Opportunity (after insert, after update) {

	if (Trigger.isInsert || Trigger.isUpdate) {
		Set<Id> oppIdSet = new Set<Id>();
		for (Opportunity opp : Trigger.new) oppIdSet.add(opp.Id);
		for (Opportunity opp : Trigger.new) {
			System.debug('TRIGGER OppId: ' + opp);

			CBGMOpportunityDomain.populateOpportunityMap(oppIdSet);
			CBGMOpportunityDomain.updateCBMapping(opp.Id);
			CBGMOpportunityDomain.updateBudgetLines(opp.Id);
			CBGMOpportunityDomain.updateContractValues(opp.Id);
			CBGMOpportunityDomain.updateOpportunityWarnings(opp.Id);
		}
	}

}