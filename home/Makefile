.phony: axeigo-forms-2026 ssh-lab celeste olympus

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

celeste:
	legendary launch Salt --no-wine --override-exe CelesteLauncher.sh --offline

olympus:
	/home/ocp/Games/Olympus/olympus-launch.sh
