#!/usr/bin/ruby
require 'erb'

# Determines package name from the origin url on github. It's hackish, but it
# works (mostly).
def pkgname
  # originurl = `basename $(git config --get remote.origin.url)`.strip
  pkgname = `basename $(git config --get remote.origin.url) .git | tr '\n' ' '`
  # _, pkgname = originurl.match(/\/([a-z0-9\-_]+).git/i).to_a
  pkgname
end

# Accepts a hash of git log data and returns a properly formatted debian 
# changelog entry.
def debchangelog(logdata)
  template = <<-EOF
<%=PKGNAME%> (<%=logdata[:tag]%>) unstable; urgency=low

  * <%=logdata[:subj]%>

 -- <%=logdata[:name]%>  <%=logdata[:date]%>

EOF
  ERB.new(template).result(binding)
end

# Checks to see if the repository has any tags already.
def repo_has_tag?
  `git describe --tags 2>&1`
  return ($? == 0)? true : false
end

# If the repository has no tags, we need to make one so we can get some kind 
# of versioning number for the changelog.
def make_temporary_tag
  firstcommit = `git log --format=%H | tail -1`.strip
  `git tag #{TEMPTAG} #{firstcommit}`
end

# Removes the tag we added if the repo had no tags.
def cleanup_temporary_tag
  `git tag -d #{TEMPTAG}`
end

# Removes jenkins build tags (if they exist)
def remove_jenkins_tags
  IO.popen("git tag -l 'jenkins-*'").readlines.each do |tag|
    `git tag -d #{tag}`
  end
end

# Get the name of this repository
PKGNAME = pkgname

# Name for the temporary tag (only used if the repository has no tags)
TEMPTAG = 'GOPSI'
#TEMPTAG = pkgname

remove_jenkins_tags

if repo_has_tag?
  dotagcleanup = false
else
  dotagcleanup = true
  make_temporary_tag
end

# Loop through the git log output and grab four lines at a time to parse.
gitlogcmd = %{git log --pretty=format:'hash: %H%nname: %aN <%aE>%ndate: %cD%nsubj: %s'}
IO.popen(gitlogcmd).readlines.each_slice(4) do |chunk|

  temphash = {}

  # split each line on the first colon and use what's on the left as the 
  # symbols within the hash
  chunk.map { |line| line.split(/: /,2) }.each do |type, data|
    temphash[type.to_sym] = data.strip
  end

  # dig up the most recent tag which contains the commit
  temphash[:tag] = `git describe --tags #{temphash[:hash]} 2>/dev/null`.strip
  if $? != 0
    dotagcleanup = true
    make_temporary_tag
    temphash[:tag] = `git describe --tags #{temphash[:hash]}`.strip
  end

  puts debchangelog(temphash)
end

# If we added a temporary tag, let's remove it
cleanup_temporary_tag