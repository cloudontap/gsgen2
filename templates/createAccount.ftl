[#ftl]
[#-- High level objects --]
[#assign organisationObject = (organisation?eval).Organisation]
[#assign accountObject = (account?eval).Account]
[#-- Reference data --]
[#assign master = masterData?eval]
[#assign regions = master.Regions]
[#assign categories = master.Categories]
[#-- Reference Objects --]
[#assign regionObject = regions[accountObject.Region]]
[#assign categoryObject = categories["alm"]]
[#-- Key values --]
[#assign organisationId = organisationObject.Id]
[#assign accountId = accountObject.Id]
[#assign accountName = accountObject.Name]
[#assign accountDomainStem = (accountObject.Domain.Stem)!"gosource.com.au"]
[#assign accountDomainBehaviour = (accountObject.Domain.AccountBehaviour)!""]
[#switch accountDomainBehaviour]
	[#case "naked"]
		[#assign accountDomain = accountDomainStem]
		[#break]
	[#case "includeAccountId"]
	[#default]
		[#assign accountDomain = accountId + "." + accountDomainStem]
[/#switch]
[#assign regionId = regionObject.Id]
[#assign categoryId = categoryObject.Id]
{
	"AWSTemplateFormatVersion" : "2010-09-09",
	"Resources" : 
	{
		[#-- Standard S3 buckets --]
		[#assign buckets = ["credentials", "code"]]
		[#list buckets as bucket]
			"s3X${bucket}" : {
				"Type" : "AWS::S3::Bucket",
				"Properties" : {
					"BucketName" : "${bucket}.${accountDomain}",
					"Tags" : [ 
						{ "Key" : "gs:project", "Value" : "${accountId}" },
						{ "Key" : "gs:category", "Value" : "${categoryId}" }
					]
				}
			}[#if !(bucket == buckets?last)],[/#if]
		[/#list]
	},
	"Outputs" : {
		"domainXaccountXdomain" : {
			"Value" : "${accountDomain}"
		}
		[#list buckets as bucket]
			,"s3XaccountX${bucket}" : {
				"Value" : { "Ref" : "s3X${bucket}" }
			}
		[/#list]
	}

}


