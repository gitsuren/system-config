function ls_non_git {
for d in $(ls .) ; do
    if [ -d $d  ] ; then
        if [ ! -e "$d/.git" ] ; then
            echo "$d"
        fi
    fi
done
}

function ls_git {

if [ "$#" -ge 1 ] ; then
    dir=$1
else
    dir="."
fi

for d in $(ls $dir) ; do
    if [ -d $d  ] ; then
        if [ -e "$d/.git" ] ; then
            echo "$d"
        fi
    fi
done
}

function git-pull-all {
    if [ "$#" -lt 1 ] ; then
        echo "usage: git-pull-all <repolist>"
        return 1
    fi
  
    git-doall "pull" $1
}

function git-push-all {
    if [ "$#" -lt 1 ] ; then
        echo "usage: git-push-all <repolist>"
        return 1
    fi
  
    git-doall "push" $1
}

function git-doall {
    gitcmd=$1
    repolist=$2

    there=$(pwd)    
    
    for repo in $(cat $repolist) ; do
        echo "$gitcmd-ing $repo"
        cd $repo
        echo $(pwd)
        git "$gitcmd"
        cd $there
    done
}

function clone-missing-git-repos {
    if [ $# -lt 2 ] ; then
        echo "Usage <url> <file.lst>"
        return 1
    fi
    repourl=$1
    listfile=$2
    
    for repo in $(cat $listfile) ; do
        if [ ! -d $repo ] ; then
            git clone "$repourl/$repo.git" 
        fi
    done
}

function make-on-change {
    if [ $# -lt 2 ] ; then
        echo "Usage <dir>"
    fi
    dir=$1
    makewhat=$2
    while inotifywait -r -e modify $dir ; do
        make $makewhat
    done
}

function tex-spellcheck {
    for f in $@ ; do
        aspell -t -c $f
    done
}

# Create a git-controlled mirror of a CVS module
# Assumes CVSROOT has been set up correctly.
function git-cvs-mirror {
    if [ $# -lt 2 ] ; then
        echo "Found $# arguments, needed 2"
        echo "Usage git-cvs-mirror <module-name> <repo-name>"
        return 1
    fi

    if [ ! -n "$CVSROOT" ] ; then
        echo "CVSROOT not set. Set to location of the cvsroot"
        return 1
    fi


    GI="git cvsimport"
    CVS_MOD=$1
    REPO_NAME=$2
    CVSIMPORT="$GI -C $REPO_NAME -d $CVSROOT -r cvs -k $CVS_MOD"

    #GIT CVSIMPORT the module
    $CVSIMPORT
    #Create a bare clone to be the central version of truth
    git clone --bare "$REPO_NAME" "$REPO_NAME.git"

    #Create a branch to handle the CVS integration.
    pushd .
    if [ -d "$REPO_NAME" ] ; then
        cd "$REPO_NAME"
    else
        echo "Could not find dir $REPO_NAME. Did the cvsimport fail?"
        return 1
    fi
    git checkout -b cvsintegration
    git checkout master
    popd
}

function fix-git-ws-errors {
    gitroot=$(git rev-parse --show-toplevel)

    if [ -z "$gitroot" ] ; then
        echo "Not a git repo. Exiting."
        return 1
    else
        #save the curren dir to return to when finished
        pushd .
        #move to the root, ensure path names correct
        cd "$gitroot"
    fi

    if git rev-parse --verify HEAD >/dev/null 2>&1 ; then
       against=HEAD
    else
       # Initial commit: diff against an empty tree object
       against=4b825dc642cb6eb9a060e54bf8d69288fbee4904
    fi

    #loop of the error messages from git diff-index looking for file/line number pairs to fix
    for fix in $(git diff-index --check --cached HEAD -- | grep "whitespace" | cut -d":" -f1,2)
    do
       file=$(echo "$fix" | cut -d: -f1)
       line=$(echo "$fix" | cut -d: -f2)

       echo "Removing trailing whitespace from $fix"
       sed -i.bak  "${line} s/[[:space:]]*$//" $file

       rm "$file.bak"
    done

    #Leave things where they were.
    popd
}

function find-todos {
    if [ $# -lt 1 ] ; then
        echo "Found $# arguments, needed at least 1."
        echo "Usage find-todos <files-to-search>"
        return 1
    fi

    for f in $* ; do
        grep -Rni 'todo\|fixme' "$f" | sed -r 's/^([^:]*:[0-9]*:)[ \t\/\*]*(.*)/\2: \1/' | sort
    done
}

