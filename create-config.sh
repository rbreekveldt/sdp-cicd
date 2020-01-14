#!/bin/bash
ansible-playbook playbooks/create-new-environment.yml -e "data_domain=dp resource_group_phase=uat project_name=onzeprj application_name=goodapp env_type=nifi sdp_admin_public=~/.ssh/sdp_pub"
