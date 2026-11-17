.phony: axeigo-forms-2026 ssh-lab

axeigo-forms-2026:
	cd /home/ocp/dev/axeigo/formularios/obradoiros && uv run main.py

ssh-lab:
	ssh ocp@ssh.lab-ocp.com

gv-api-pgcli:
	ssh -t ocp@ssh.lab-ocp.com "cd /home/ocp/docker/gv/gv-api && make pgcli-db"

rescan-wifi:
	nmcli device wifi list --rescan yes

wifi-oscar:
	nmcli device wifi list --rescan yes
	nmcli device wifi connect Oscar

windows-reboot:
	@id=$$(efibootmgr | sed -n 's/^Boot\([0-9A-F]\{4\}\)\* Windows Boot Manager.*/\1/p'); \
	[ -n "$$id" ] || { echo "no Windows Boot Manager UEFI entry"; exit 1; }; \
	sudo efibootmgr -q -n $$id && loginctl reboot
