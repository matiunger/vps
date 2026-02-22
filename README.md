# VPS Requirements

Host public websites
 - each site will have a specific domain for each site.
 - The sites have a github repo with different braches (prod, stage, dev)
 - prod should be sync with main domain
 - stage should be sync with stage domain (dev.domain.com)

 - It should automatically sync the site with the github repo.
 - I dont want to store ssh keys in the repo.
 - Site can be single html file, nextjs app, react app, etc.
 - some sites will have a sqllite database, or some local no-sql database, or a external database (ie firestore)
 - I need to manage secrets (like api keys, etc) that are not in the repo. Each environment should can have a different secret.
 - Sites should be served with HTTPS.

Host private websites
 - each site will have a specific subdomain of my personal domain.
 - site should be protected by a password.
 - site should be sync with the github repo.
 - same guidelines as public websites.

Host n8n
 - I may host n8n and want to access to webui.

Host some scripts for example python scripts, node scripts, etc. and schedule them on a specific time.