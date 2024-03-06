/*
This rule finds which functions are privileged.
A function is privileged if only one address can call it.

The rule identifies this by checking which functions can be called by two different users.

*/


rule privilegedOperation(method f, address privileged)
{
	require f.selector == sig:activateEmergencyShutdown().selector ||
			f.selector == sig:deactivateEmergencyShutdown().selector ||
			f.selector == sig:transferOwnership(address).selector ||
			f.selector == sig:acceptOwnership().selector ||
			f.selector == sig:renounceOwnership().selector;

	env e1;
	calldataarg arg;
	require e1.msg.sender == privileged;

	storage initialStorage = lastStorage;
	f@withrevert(e1, arg); // privileged succeeds executing candidate privileged operation.
	bool firstSucceeded = !lastReverted;

	env e2;
	calldataarg arg2;
	require e2.msg.sender != privileged;
	f@withrevert(e2, arg2) at initialStorage; // unprivileged
	bool secondSucceeded = !lastReverted;

	assert !(firstSucceeded && secondSucceeded), "${f.selector} can be called by both ${e1.msg.sender} and ${e2.msg.sender}, so it is not privileged";
}

rule changeEmergencyShutdownFlag()
{
	env e;
	require e.msg.sender == owner(e);

	activateEmergencyShutdown(e);
	assert emergencyShutdownActive(e), "emergencyShutdownActive flag false after activating method";

	deactivateEmergencyShutdown(e);
	assert !emergencyShutdownActive(e), "emergencyShutdownActive flag true after DEactivating method";
}
