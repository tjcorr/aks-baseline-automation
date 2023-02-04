<<<<<<< HEAD
=======


Recommended Changes
>>>>>>> e7159175e6d2b8a007871502e55e83bdad415507

Recommended Changes
•	The workflow is set to be triggered by a manual execution with user input for the settings. This limits the ability for users to manage the infrastructure on an ongoing basis. The inputs should be converted to either a parameter file or GitHub secrets (or soon variables). This allows us to build CI/CD workflows for the AKS environment.
•	Should “Check Preview Features” be part of every workflow or should we just move it to the pre-requisite section to eliminate the need to run it for every execution? It takes under 30 seconds so probably not a huge deal either way. The main question to me is are these features normally disabled in a subscription? If so are we OK suggesting preview features in a reference architecture?
•	Can “Cert Generation” be completed outside of the workflow as part of prerequisites? Otherwise, the workflow isn’t idempotent. The certs should probably land in KeyVault somewhere. Worst case we should upload them as part of the workflow that way we can check for existence and just reuse what is there already. Alternatively this can be done with a deployment script (see below).
•	For the “simple” case where one team is managing all the components, we should create a meta module that collapses all 5 different deployments into a single step. This will allow for a single what-if / deploy pipeline to simplify approval processes and eliminate dependency issues. Otherwise we need to create a separate workflow for each step and any commit with changes in multiple deployments would just break.
•	Can we do without loading the standard docker images into our ACR? I’m assuming this is done for security and/or performance reasons. Unfortunately, it forces us into using multiple deployments. Otherwise we should investigate using a deployment script (see:  https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/deployment-script-bicep) to do this directly in Bicep.  
•	For “cert_import” this should either check if steps are already done or be converted to a deployment_script.