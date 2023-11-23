/**
 * Created by Alex JR on 11/8/2023.
 */

trigger CBGMOpportunityTrigger on Opportunity (after insert, after update) {

	if (Trigger.isInsert || Trigger.isUpdate) {
		Opportunity opp = Trigger.new[0];
		CBGMOpportunityTriggerDomain.updateCBMapping(opp.Id);
		CBGMOpportunityTriggerDomain.updateBudgetLines(opp.Id);

	}

}