all:

rebase:
	git rebase HEAD # ensure that there are no uncommitted changes
	git remote show upstream || git remote add upstream git://github.com/sunaku/wmiirc.git
	git fetch upstream
	git rebase upstream/master

branch: rebase
	git checkout -b personal
	git checkout upstream/personal -- config.yaml
	@echo '---------------------------------------------------------------'
	@echo 'IMPORTANT: You must now edit config.yaml to suit your needs ...'
	@echo '---------------------------------------------------------------'

rumai:
	git clone git://github.com/sunaku/rumai.git
	sed '2a$$:.unshift File.expand_path("../rumai/lib", __FILE__)' -i wmiirc
