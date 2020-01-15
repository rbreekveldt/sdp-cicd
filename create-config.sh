#!/bin/bash
ansible-playbook playbooks/create-new-environment.yml -e "data_domain=monitoring resource_group_phase=uat project_name=secuPI application_name=badapp env_type=nifi sdp_admin_public=~/.ssh/sdp_pub project_description='Bad project'"

