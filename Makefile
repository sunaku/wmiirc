all:

rebase:
	git rebase HEAD # ensure that there are no uncommitted changes
	git remote show upstream || git remote add upstream git://github.com/sunaku/wmiirc.git
	git fetch upstream
	git rebase upstream/master

branch:
	git checkout -b personal
	cp -vb EXAMPLE.config.yaml config.yaml
	$(EDITOR) config.yaml

rumai:
	git clone git://github.com/sunaku/rumai.git
	sed '2a$$:.unshift File.expand_path("../rumai/lib", __FILE__)' -i wmiirc
