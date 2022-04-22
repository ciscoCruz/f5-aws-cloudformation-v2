#  expectValue = "StackId"
#  scriptTimeout = 10
#  replayEnabled = false
#  replayTimeout = 0


TMP_DIR='/tmp/<DEWPOINT JOB ID>'
src_ip=$(curl ifconfig.me)/32
bucket_name=`echo <STACK NAME>|cut -c -60|tr '[:upper:]' '[:lower:]'| sed 's:-*$::'`
echo "bucket_name=$bucket_name"

runtimeConfig='"<UPDATE CONFIG>"'
secret_arn=$(aws secretsmanager describe-secret --secret-id <DEWPOINT JOB ID>-secret-runtime --region <REGION> | jq -r .ARN)
secret_name=$(aws secretsmanager describe-secret --secret-id <DEWPOINT JOB ID>-secret-runtime --region <REGION> | jq -r .Name)

bigiq_stack_name=<STACK NAME>-bigiq
bigiq_stack_region=<REGION>
if [ -f "${TMP_DIR}/bigiq_info.json" ]; then
    echo "Found existing BIG-IQ"
    cat ${TMP_DIR}/bigiq_info.json
    bigiq_stack_name=$(cat ${TMP_DIR}/bigiq_info.json | jq -r .bigiq_stack_name)
    bigiq_stack_region=$(cat ${TMP_DIR}/bigiq_info.json | jq -r .bigiq_stack_region)
    bigiq_password=$(cat ${TMP_DIR}/bigiq_info.json | jq -r .bigiq_password)
fi

bigiq_address=$(aws cloudformation describe-stacks --region $bigiq_stack_region --stack-name $bigiq_stack_name | jq -r '.Stacks[].Outputs[]|select (.OutputKey=="device1ManagementEipAddress")|.OutputValue')

if [[ "<UPDATE CONFIG>" == *{* ]]; then
    config_with_added_address="${runtimeConfig//<BIGIQ ADDRESS>/$bigiq_address}"
    config_with_added_secret_id="${config_with_added_address//<SECRET_ID>/$secret_name}"
    config_with_all_replaced_values="${config_with_added_secret_id//<BUCKET_ID>/$bucket_name}"
    runtimeConfig=$config_with_all_replaced_values
fi

echo "Runtime Init Config: $runtimeConfig"

region=$(aws s3api get-bucket-location --bucket $bucket_name | jq -r .LocationConstraint)

if [ -z $region ] || [ $region == null ]; then
    region="us-east-1"
    echo "bucket region:$region"
else
    echo "bucket region:$region"
fi

# create a new bucket if deploying telemetry, otherwise pass existing bucket
if [[ <CREATE LOG DESTINATION> == "true" ]]; then
    logging_bucket_name="<DEWPOINT JOB ID>-logging-s3"
else
    logging_bucket_name=$bucket_name
fi

# Set Parameters using file to eiliminate issues when passing spaces in parameter values
cat <<EOF > parameters.json
[
    {
        "ParameterKey": "application",
        "ParameterValue": "f5-app-<DEWPOINT JOB ID>"
    },
    {
        "ParameterKey": "appScalingMaxSize",
        "ParameterValue": "<APP SCALE MAX SIZE>"
    },
    {
        "ParameterKey": "appScalingMinSize",
        "ParameterValue": "<APP SCALE MIN SIZE>"
    },
    {
        "ParameterKey": "bastionScalingMaxSize",
        "ParameterValue": "<BASTION SCALE MAX SIZE>"
    },
    {
        "ParameterKey": "bastionScalingMinSize",
        "ParameterValue": "<BASTION SCALE MIN SIZE>"
    },
    {
        "ParameterKey": "bigIpCustomImageId",
        "ParameterValue": "<CUSTOM IMAGE ID>"
    },
    {
        "ParameterKey": "bigIpImage",
        "ParameterValue": "<BIGIP IMAGE>"
    },
    {
        "ParameterKey": "bigIpInstanceType",
        "ParameterValue": "<BIGIP INSTANCE TYPE>"
    },
    {
        "ParameterKey": "bigIpRuntimeInitConfig",
        "ParameterValue": $runtimeConfig
    },
    {
        "ParameterKey": "bigIpRuntimeInitPackageUrl",
        "ParameterValue": "<BIGIP RUNTIME INIT PACKAGEURL>"
    },
    {
        "ParameterKey": "bigIpScaleInCpuThreshold",
        "ParameterValue": "<LOW CPU THRESHOLD>"
    },
    {
        "ParameterKey": "bigIpScaleInThroughputThreshold",
        "ParameterValue": "<SCALE DOWN BYTES THRESHOLD>"
    },
    {
        "ParameterKey": "bigIpScaleOutCpuThreshold",
        "ParameterValue": "<HIGH CPU THRESHOLD>"
    },
    {
        "ParameterKey": "bigIpScaleOutThroughputThreshold",
        "ParameterValue": "<SCALE UP BYTES THRESHOLD>"
    },
    {
        "ParameterKey": "bigIqAddressType",
        "ParameterValue": "public"
    },
    {
        "ParameterKey": "bigIqSecretArn",
        "ParameterValue": "$secret_arn"
    },
    {
        "ParameterKey": "lambdaS3BucketName",
        "ParameterValue": "f5-aws-bigiq-revoke"
    },
    {
        "ParameterKey": "lambdaS3Key",
        "ParameterValue": "develop/"
    },
    {
        "ParameterKey": "bigIpMaxBatchSize",
        "ParameterValue": "<UPDATE MAX BATCH SIZE>"
    },
    {
        "ParameterKey": "metricNameSpace",
        "ParameterValue": "<METRIC NAME SPACE>"
    },
    {
        "ParameterKey": "bigIpMinInstancesInService",
        "ParameterValue": "<UPDATE MIN INSTANCES>"
    },
    {
        "ParameterKey": "notificationEmail",
        "ParameterValue": "<NOTIFICATION EMAIL>"
    },
    {
        "ParameterKey": "bigIpPauseTime",
        "ParameterValue": "<UPDATE PAUSE TIME>"
    },
    {
        "ParameterKey": "numAzs",
        "ParameterValue": "<NUMBER AZS>"
    },
    {
        "ParameterKey": "numSubnets",
        "ParameterValue": "<NUMBER SUBNETS>"
    },
    {
        "ParameterKey": "provisionExternalBigipLoadBalancer",
        "ParameterValue": "<PROVISION EXTERNAL LB>"
    },
    {
        "ParameterKey": "provisionInternalBigipLoadBalancer",
        "ParameterValue": "<PROVISION INTERNAL LB>"
    },
    {
        "ParameterKey": "provisionPublicIp",
        "ParameterValue": "<PROVISION PUBLIC IP>"
    },
    {
        "ParameterKey": "restrictedSrcAddressApp",
        "ParameterValue": "$src_ip"
    },
    {
        "ParameterKey": "restrictedSrcAddressMgmt",
        "ParameterValue": "$src_ip"
    },
    {
        "ParameterKey": "s3BucketName",
        "ParameterValue": "$bucket_name"
    },
    {
        "ParameterKey": "s3BucketRegion",
        "ParameterValue": "$region"
    },
    {
        "ParameterKey": "cloudWatchLogGroupName",
        "ParameterValue": "<UNIQUESTRING>-<CLOUDWATCH LOG GROUP NAME>"
    },
    {
        "ParameterKey": "cloudWatchLogStreamName",
        "ParameterValue": "<UNIQUESTRING>-<CLOUDWATCH LOG STREAM NAME>"
    },
    {
        "ParameterKey": "cloudWatchDashboardName",
        "ParameterValue": "<UNIQUESTRING>-<CLOUDWATCH DASHBOARD NAME>"
    },
    {
        "ParameterKey": "createLogDestination",
        "ParameterValue": "<CREATE LOG DESTINATION>"
    },
    {
        "ParameterKey": "loggingS3BucketName",
        "ParameterValue": "$logging_bucket_name"
    },
    {
        "ParameterKey": "secretArn",
        "ParameterValue": "$secret_arn"
    },
    {
        "ParameterKey": "snsEvents",
        "ParameterValue": "<SNS EVENTS>"
    },
    {
        "ParameterKey": "sshKey",
        "ParameterValue": "<SSH KEY>"
    },
    {
        "ParameterKey": "subnetMask",
        "ParameterValue": "<SUBNETMASK>"
    },
    {
        "ParameterKey": "uniqueString",
        "ParameterValue": "<UNIQUESTRING>"
    },
    {
        "ParameterKey": "vpcCidr",
        "ParameterValue": "<CIDR>"
    }
]
EOF

cat parameters.json

aws cloudformation update-stack --use-previous-template --region <REGION> --stack-name <STACK NAME> --tags Key=creator,Value=dewdrop Key=delete,Value=True \
--capabilities CAPABILITY_IAM \
--parameters file://parameters.json
