# Neura DevOps Exercise - Yoad Submission
## INTRO
Hey! this is my submission of the CHEF excercise, hope you'd like it :)

### Actions

* I've created the requested cookbook (hopefully :) ) with its dependencies (basing some of the https://supermarket.chef.io/cookbooks/teamcity-cookbook funciontality).
* I've added postgres as the external db for the app.
* The cookbook shall do the configuration automatically: set data path, configure DB, accept-agreement, create admin-user.
* The admin-user defined by default is teamcity, with default password of teamcity. you can change in the attributes file.
* This has been tested on ubuntu trusty (14.04).

#### How To Run

* Install chef-solo (This has been teseted on version 12.20.3), please install it with: curl -LO https://omnitruck.chef.io/install.sh && sudo bash ./install.sh -v 12.20.3 && rm install.sh
* Clone the repository
* cd to the repository's root folder and run "chef-solo -c solo.rb -j teamcity.json"
* Be patient :) download file is big and teamcity self-configuration takes a while
* You'll notice a stage where the cookbook will wait for the license agreement, this is the stage you can browse to the service and then wait for it to finish the self configuration (you can ignore the create admin page when it loads, admin user is already created automatically according to chef's attributes file)

#### TODO IN PRODUCTION

* check if db exists --> back it up, and delete it for clean installation.
* verify chef version and adjust accordingly.
* verify the apt-get is not broken ahead.
* Check ps, if catalina is still up after graceful shutdown - kill it forecfully.
* Fail the book on mandatory steps i forgot?
* Create an init.d script.
* Notify the user by mail when the cookbook is completely done (parse the teamcity logs).
* Wrap the whole run with python/bash for "dummy" deployment.
* Skip the create admin page as admin user has been created already, and skip to main page.
