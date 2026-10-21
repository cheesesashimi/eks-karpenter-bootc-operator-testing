.PHONY: setup teardrown refresh

TOFU ?= tofu

setup:
	$(TOFU) -chdir=eks init
	$(TOFU) -chdir=eks apply -auto-approve
	$(TOFU) -chdir=addons init
	$(TOFU) -chdir=addons apply -auto-approve
	$(TOFU) -chdir=agent-kubeconfig init
	$(TOFU) -chdir=agent-kubeconfig apply -auto-approve

restart-bootc-operator:
	kubectl rollout restart deployment/bootc-operator-controller -n bootc-operator
	kubectl rollout restart daemonset/bootc-operator-daemon -n bootc-operator

teardown:
	$(TOFU) -chdir=agent-kubeconfig destroy -auto-approve
	$(TOFU) -chdir=addons destroy -auto-approve
	$(TOFU) -chdir=eks destroy -auto-approve

refresh:
	$(TOFU) -chdir=addons apply -auto-approve
	$(TOFU) -chdir=agent-kubeconfig apply -auto-approve
