#!/bin/sh
# Invalidate cloudfront

if [ -z "$1" ] || [ -z "$2" ]
  then
    echo "sh deploy.sh source target"
		exit 1
fi


if [ ! -d $1 ]; then
  echo "Please check if the source existss..."
	exit 1
fi

s3_bucket=$BUCKET_NAME
distribution_id=$DISTRIBUTION_ID
profile=$AWS_PROFILE
path=$1
key=$2

echo "source $1"
echo "target $2"

echo "Starting deployment"


invalidate_cf()
{
    # distribution_id=$1
		echo "distribution Id $distribution_id"
    aws cloudfront create-invalidation --distribution-id $distribution_id --path "$key/*" --profile $profile
}
invalidate_cf_and_wait()
{
    # distribution_id=$1
    id=$(invalidate_cf $distribution_id | grep Id | awk -F'"' '{ print $4}' )
    echo "Waiting for invalidation $id "
    aws cloudfront wait invalidation-completed --id $id --distribution-id $distribution_id --profile $profile
    echo "Invalidation $id completed"
}

check_if_path_exists()
{
	echo "Checking if the target exists"
	totalFoundObjects=$(aws s3 ls s3://${s3_bucket}/${key} --recursive --summarize  --profile $profile | grep "Total Objects: " | sed 's/[^0-9]*//g')
if [ "$totalFoundObjects" -eq "0" ]; then
   echo "There are no files found"
	 return 0
else
  echo "Objects found: $totalFoundObjects"
	return 1
fi
}

check_if_path_exists
already_exists=$?
if [ "$already_exists" -eq "1" ];
then
	# echo "Key already exists. Replace?(yes/No)"
	read -p "Target already exists. Replace?(yes/no)?" REPLACE

	echo "replace  $REPLACE"
	if [ $REPLACE != "yes" ]
	then 
	# echo "Removing old files"
	# aws s3 rm s3://${s3_bucket}/${key}
	exit 1
	fi
fi


echo "Starting s3 copy"

aws s3 sync $path  s3://${s3_bucket}/${key} \
--cache-control 'public, max-age=3600, immutable' \
--delete \
--exclude '.git/*' --exclude '.gitignore' --exclude '.vscode' \
--profile $profile
if [ "$already_exists" -eq "1" ];
then 
	echo "Starting cloudfront invalidation"
	invalidate_cf_and_wait $distribution_id
fi
echo "Finished deployment"
