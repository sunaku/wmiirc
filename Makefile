all:

rebase:
	git rebase HEAD # ensure that there are no uncommitted changes
	git remote show upstream || git remote add upstream git://github.com/sunaku/wmiirc.git
	git fetch upstream
	git rebase upstream/master

branch:
	git checkout -b personal
	cp -vb EXAMPLE.config.yaml config.yaml
	@echo '---------------------------------------------------------------'
	@echo 'IMPORTANT: You must now edit config.yaml -- fill in the blanks!'
	@echo '---------------------------------------------------------------'

rumai:
	git clone git://github.com/sunaku/rumai.git
	sed '2a$$:.unshift File.expand_path("../rumai/lib", __FILE__)' -i wmiirc
