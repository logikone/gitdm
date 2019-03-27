#!/bin/bash
function cleanup {
  git checkout master src/cncf-config/email-map src/github_users.json
  rm -rf cncf-config github_users.json err out 2>/dev/null
}

trap cleanup EXIT

function analysis {
  #notchecked=`grep -E '"affiliation": ("\(Unknown\)"|""|"\?"|"-"|null)' "$3" | wc -l`
  #notfound=`grep 'NotFound' "$2" | wc -l`
  #found=`grep -E '[^\s!]+![^\s!]+' "$2" | wc -l`
  #echo "$1,$found,$notfound,$notchecked" >> src/burndown.csv
  echo "Analysing date $1, files $2 $3"
  git checkout $4 src/actors.txt src/actors_cncf.txt 1>/dev/null 2>/dev/null || git checkout src/actors.txt src/actors_cncf.txt 1>/dev/null 2>/dev/null
  echo -n "$1," >> src/burndown.csv
  ruby src/calc_affs_stats.rb "$2" "$3" src/actors.txt src/actors_cncf.txt >> src/burndown.csv
}

if [ -z "$1" ]
then
  since="2017-03-01"
else
  since="$1"
fi

if [ -z "$2" ]
then
  until="2099-01-01"
else
  until="$2"
fi

> src/burndown.csv

commits=`git log --format=format:'%H;%ci' --since "$since" --until "$until"`
last_date=''
for commit_data in $commits
do
  IFS=';'
  arr=($commit_data)
  unset IFS
  commit=${arr[0]}
  len=${#commit}
  if [ ! "$len" = "40" ]
  then
    continue
  fi
  date=${arr[1]}
  if [ "$date" = "$last_date" ]
  then
    continue
  fi
  last_date=$date
  # echo "Date: $date, commit: $commit"
  em='src/cncf-config/email-map'
  gu='src/github_users.json'
  git checkout $commit $em $gu 1>/dev/null 2>/dev/null
  res=$?
  if [ ! "$res" = "0" ]
  then
    em='cncf-config/email-map'
    gu='github_users.json'
    git checkout $commit $em $gu 1>out 2>err
    res=$?
    if [ "$res" = "0" ]
    then
      analysis $date $em $gu $commit
    else
      echo "failed $commit, last date: $last_date"
      echo "stdout:"
      cat out
      echo "stderr:"
      cat err
    fi
  else
    analysis $date $em $gu $commit
  fi
done

cat src/burndown.csv | sort | uniq > out
echo 'Date,All Not Found,All Found,All Not Checked,CNCF Not Found,CNCF Found,CNCF Not Checked' > src/burndown.csv
cat out >> src/burndown.csv
rm out

cleanup
