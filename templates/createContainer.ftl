[#ftl]
[#-- High level objects --]
[#assign organisationObject = (organisation?eval).Organisation]
[#assign accountObject = (account?eval).Account]
[#assign projectObject = (project?eval).Project]
[#assign solutionObject = (solution?eval).Solution]
[#assign solutionTiers = solutionObject.Tiers]
[#assign solutionContainer = solutionObject.Container]
[#-- Container --]
[#assign containerObject = (container?eval).Container]
[#-- Outputs from existing stacks --]
[#assign stacksList = stacks?eval]
[#assign stacks = []]
[#list stacksList as stack]
  [#assign stackEvaluation = "(" + stack + "?eval).Stacks[0]"]
  [#assign json = stackEvaluation?eval]
  [#assign stacks = stacks + [json]]
[/#list][#-- Reference data --]
[#assign master = masterData?eval]
[#assign regions = master.Regions]
[#assign environments = master.Environments]
[#assign categories = master.Categories]
[#assign tiers = master.Tiers]
[#assign routeTables = master.RouteTables]
[#assign networkACLs = master.NetworkACLs]
[#assign processors = master.Processors]
[#-- Reference Objects --]
[#assign regionObject = regions[containerObject.Region!(solutionObject.Region!accountObject.Region)]]
[#assign accountRegionObject = regions[accountObject.Region]]
[#assign environmentObject = environments[containerObject.Environment]]
[#assign categoryObject = categories[containerObject.Category!environmentObject.Category]]
[#-- Key values --]
[#assign organisationId = organisationObject.Id]
[#assign accountId = accountObject.Id]
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
[#assign accountRegionId = accountRegionObject.Id]
[#assign projectId = projectObject.Id]
[#assign projectName = projectObject.Name]
[#assign containerId = containerObject.Id!environmentObject.Id]
[#assign containerName = containerObject.Name!environmentObject.Name]
[#-- Note that checking of solution object for doamin overrides is deprecated. --]
[#-- Project leve domain overrides should be done in project.json to allow solution.json to be shared across dev/prod environments --]
[#assign containerDomainStem = (containerObject.Domain.Stem)!(solutionObject.Domain.Stem)!(projectObject.Domain.Stem)!(accountObject.Domain.Stem)!"gosource.com.au"]
[#assign containerDomainBehaviour = (containerObject.Domain.ContainerBehaviour)!(solutionObject.Domain.ContainerBehaviour)!(projectObject.Domain.ContainerBehaviour)!(accountObject.Domain.ContainerBehaviour)!""]
[#switch containerDomainBehaviour]
	[#case "naked"]
		[#assign containerDomain = containerDomainStem]
		[#break]
	[#case "includeContainerName"]
		[#assign containerDomain = containerName + "." + containerDomainStem]
		[#break]
	[#case "includeProjectId"]
	[#default]
		[#assign containerDomain = containerName + "." + projectId + "." + containerDomainStem]
[/#switch]
[#assign regionId = regionObject.Id]
[#assign environmentId = environmentObject.Id]
[#assign environmentName = environmentObject.Name]
[#assign categoryId = categoryObject.Id]
[#assign bClass = containerObject.BClass!solutionContainer.BClass]
[#assign internetAccess = containerObject.InternetAccess!solutionContainer.InternetAccess]
[#assign dnsSupport = containerObject.DNSSupport!solutionContainer.DNSSupport]
[#assign dnsHostnames = containerObject.DNSHostnames!solutionContainer.DNSHostnames]
[#assign jumpServer = internetAccess && (containerObject.NAT?? || solutionContainer.NAT??)]
[#assign jumpServerPerAZ = jumpServer && (containerObject.NAT!solutionContainer.NAT).MultiAZ]
[#assign sshPerContainer = containerObject.SSHPerContainer!solutionObject.SSHPerContainer]

[#assign credentialsBucket = "credentials." + accountDomain]
[#assign codeBucket = "code." + accountDomain]
[#assign configurationBucket = "configuration." + accountDomain]

[#assign logsBucket = "logs." + containerDomain]
[#assign backupsBucket = "backups." + containerDomain]

[#assign logsExpiration = (containerObject.Logs.Expiration)!(solutionObject.Logs.Expiration)!(environmentObject.Logs.Expiration)!90]
[#assign backupsExpiration = (containerObject.Backups.Expiration)!(solutionObject.Backups.Expiration)!(environmentObject.Backups.Expiration)!365]

[#-- Optimise some repeated loops --]
[#assign lastTier = solutionTiers?last]
[#assign firstZone = regionObject.Zones?first]
[#assign lastZone = regionObject.Zones?last]

[#function getKey key]
  [#list stacks as stack]
    [#list stack.Outputs as pair]
      [#if pair.OutputKey==key]
        [#return pair.OutputValue]
      [/#if]
    [/#list]
  [/#list]
[/#function]

[#function getProcessor tier component type]
    [#assign tc = tier.Id + "-" + component.Id]
    [#assign defaultProfile = "default"]
    [#if (containerObject.Processor[tc])??]
    	[#return containerObject.Processor[tc]]
    [/#if]
    [#if (containerObject.Processor[type])??]
    	[#return containerObject.Processor[type]]
    [/#if]
    [#if (component[type].Processor)??]
    	[#return component[type].Processor]
    [/#if]
    [#if (solutionObject.Processor[tc])??]
    	[#return solutionObject.Processor[tc]]
    [/#if]
    [#if (solutionObject.Processor[type])??]
    	[#return solutionObject.Processor[type]]
    [/#if]
    [#if (processors[containerObject.CapacityProfile][tc])??]
    	[#return processors[containerObject.CapacityProfile][tc]]
    [/#if]
    [#if (processors[containerObject.CapacityProfile][type])??]
    	[#return processors[containerObject.CapacityProfile][type]]
    [/#if]
    [#if (processors[solutionObject.CapacityProfile][tc])??]
    	[#return processors[solutionObject.CapacityProfile][tc]]
    [/#if]
    [#if (processors[solutionObject.CapacityProfile][type])??]
    	[#return processors[solutionObject.CapacityProfile][type]]
    [/#if]
    [#if (processors[defaultProfile][tc])??]
    	[#return processors[defaultProfile][tc]]
    [/#if]
    [#if (processors[defaultProfile][type])??]
    	[#return processors[defaultProfile][type]]
    [/#if]
[/#function]
{
  "AWSTemplateFormatVersion" : "2010-09-09",
  "Resources" : 
  {
    [#assign sliceCount = 0]
	[#if !(slice??) || (slice?contains("eip"))]
		[#-- Define EIPs --]
		[#assign eipCount = 0]
        [#if jumpServer]
		    [#assign tier = tiers["mgmt"]]
		    [#list regionObject.Zones as zone]
			    [#if jumpServerPerAZ || firstZone.Id = zone.Id]
			        [#if eipCount > 0],[/#if]
				    "eipX${tier.Id}XnatX${zone.Id}": {
				        "Type" : "AWS::EC2::EIP",
				        "Properties" : {
				  	        "Domain" : "vpc"
				        }
				    }
				    [#assign eipCount = eipCount + 1]
				[/#if]
		    [/#list]
		    [#assign sliceCount = sliceCount + 1]
		[/#if]
    [/#if]
	[#if !(slice??) || (slice?contains("vpc"))]
		[#-- Define VPC --]
		[#if sliceCount > 0],[/#if]"vpc" : {
		  "Type" : "AWS::EC2::VPC",
		  "Properties" : {
			"CidrBlock" : "${bClass}.0.0/16",
			"EnableDnsSupport" : ${(dnsSupport)?string("true","false")},
			"EnableDnsHostnames" : ${(dnsHostnames)?string("true","false")},
			"Tags" : [ 
			  { "Key" : "gs:account", "Value" : "${accountId}" },
			  { "Key" : "gs:project", "Value" : "${projectId}" },
			  { "Key" : "gs:container", "Value" : "${containerId}" },
			  { "Key" : "gs:environment", "Value" : "${environmentId}" },
			  { "Key" : "gs:category", "Value" : "${categoryId}" },
			  { "Key" : "Name", "Value" : "${projectName}-${containerName}" } 
			]
		  }
		}
		[#-- Define Internet Gateway and connect it to the VPC --]
		[#if internetAccess]
		  ,"igw" : {
			"Type" : "AWS::EC2::InternetGateway",
			"Properties" : {
			  "Tags" : [ 
				{ "Key" : "gs:account", "Value" : "${accountId}" },
				{ "Key" : "gs:project", "Value" : "${projectId}" },
				{ "Key" : "gs:container", "Value" : "${containerId}" },
				{ "Key" : "gs:environment", "Value" : "${environmentId}" },
				{ "Key" : "gs:category", "Value" : "${categoryId}" },
				{ "Key" : "Name", "Value" : "${projectName}-${containerName}" } 
			  ]
			}
		  },
		  "igwXattachment" : {
			"Type" : "AWS::EC2::VPCGatewayAttachment",
			"Properties" : {
			  "InternetGatewayId" : { "Ref" : "igw" },
			  "VpcId" : { "Ref" : "vpc" }
			}
		  }
		[/#if]
		[#-- Define route tables --]
		[#assign solutionRouteTables = []]
		[#list solutionTiers as solutionTier]
			[#assign tier = tiers[solutionTier.Id]]
			[#assign routeTable = routeTables[solutionTier.RouteTable!tier.RouteTable]]
			[#list regionObject.Zones as zone]
				[#assign tableId = routeTable.Id + jumpServerPerAZ?string("X" + zone.Id,"")]
				[#assign tableName = routeTable.Name + jumpServerPerAZ?string("-" + zone.Id,"")]
				[#if !solutionRouteTables?seq_contains(tableId)]
					[#assign solutionRouteTables = solutionRouteTables + [tableId]]
					,"routeTableX${tableId}" :
					{
						"Type" : "AWS::EC2::RouteTable",
						"Properties" : 
						{
							"VpcId" : { "Ref" : "vpc" },
							"Tags" : [ 
							  { "Key" : "gs:account", "Value" : "${accountId}" },
							  { "Key" : "gs:project", "Value" : "${projectId}" },
							  { "Key" : "gs:container", "Value" : "${containerId}" },
							  { "Key" : "gs:environment", "Value" : "${environmentId}" },
							  { "Key" : "gs:category", "Value" : "${categoryId}" },
							  [#if jumpServerPerAZ]
								{ "Key" : "gs:zone", "Value" : "${zone.Id}" },
							  [/#if]
							  { "Key" : "Name", "Value" : "${projectName}-${containerName}-${tableName}" } 
							]
						}
					}
					[#list routeTable.Routes as route]
						,"routeX${tableId}X${route.Id}" : {
							"Type" : "AWS::EC2::Route",
							"Properties" : {
								"RouteTableId" : { "Ref" : "routeTableX${tableId}" },
								[#switch route.Type]
									[#case "gateway"]
										"DestinationCidrBlock" : "0.0.0.0/0",
										"GatewayId" : { "Ref" : "igw" }						
									[#break]
								[/#switch]
								}
						}
					[/#list]
				[/#if]
			[/#list]
		[/#list]
		[#-- Define network ACLs --]
		[#assign solutionNetworkACLs = []]
		[#list solutionTiers as solutionTier]
			[#assign tier = tiers[solutionTier.Id]]
			[#assign networkACL = networkACLs[solutionTier.NetworkACL!tier.NetworkACL]]
			[#if !solutionNetworkACLs?seq_contains(networkACL.Id)]
				[#assign solutionNetworkACLs = solutionNetworkACLs + [networkACL.Id]]
				,"networkACLX${networkACL.Id}" : 
				{
					"Type" : "AWS::EC2::NetworkAcl",
					"Properties" : 
					{
						"VpcId" : { "Ref" : "vpc" },
						"Tags" : [ 
						  { "Key" : "gs:account", "Value" : "${accountId}" },
						  { "Key" : "gs:project", "Value" : "${projectId}" },
						  { "Key" : "gs:container", "Value" : "${containerId}" },
						  { "Key" : "gs:environment", "Value" : "${environmentId}" },
						  { "Key" : "gs:category", "Value" : "${categoryId}" },
						  { "Key" : "Name", "Value" : "${projectName}-${containerName}-${networkACL.Name}" } 
						]
					}
				}
	
				[#list ["Inbound", "Outbound"] as direction]
					[#if networkACL.Rules[direction]??]
						[#list networkACL.Rules[direction] as rule]
						,"ruleX${networkACL.Id}X${(direction="Outbound")?string("out", "in")}X${rule.Id}" : 
						{
							"Type" : "AWS::EC2::NetworkAclEntry",
							"Properties" : 
							{
								"NetworkAclId" : { "Ref" : "networkACLX${networkACL.Id}" },
								"Egress" : "${(direction="Outbound")?string("true","false")}",
								"RuleNumber" : "${rule.RuleNumber}",
								"RuleAction" : "${rule.Allow?string("allow","deny")}",
								"CidrBlock" : "${rule.CIDRBlock}",
								[#switch rule.Protocol]
									[#case "all"]
										"Protocol" : "-1",
										"PortRange" : { "From" : "${((rule.PortRange.From)!0)?c}", "To" : "${((rule.PortRange.To)!65535)?c}"}
										[#break]
									[#case "icmp"]
										"Protocol" : "1",
										"Icmp" : {"Code" : "${((rule.ICMP.Code)!-1)?c}", "Type" : "${((rule.ICMP.Type)!-1)?c}"}
										[#break]
									[#case "udp"]
										"Protocol" : "17",
										"PortRange" : { "From" : "${((rule.PortRange.From)!0)?c}", "To" : "${((rule.PortRange.To)!65535)?c}"}
										[#break]
									[#case "tcp"]
										"Protocol" : "6",
										"PortRange" : { "From" : "${((rule.PortRange.From)!0)?c}", "To" : "${((rule.PortRange.To)!65535)?c}"}
										[#break]
								[/#switch]
							}
						}
						[/#list]
					[/#if]
				[/#list]
			[/#if]
		[/#list]  	
		[#list solutionTiers as solutionTier]
			[#assign tier = tiers[solutionTier.Id]]
			[#assign routeTable = routeTables[solutionTier.RouteTable!tier.RouteTable]]
			[#assign networkACL = networkACLs[solutionTier.NetworkACL!tier.NetworkACL]]
			[#list regionObject.Zones as zone]
				,"subnetX${tier.Id}X${zone.Id}" : 
				{
				  "Type" : "AWS::EC2::Subnet",
				  "Properties" : 
				  {
					"VpcId" : { "Ref" : "vpc" },
					"AvailabilityZone" : "${zone.AWSZone}",
					"CidrBlock" : "${bClass}.${tier.StartingCClass+zone.CClassOffset}.0/${zone.CIDRMask}",
					"Tags" : [
					  { "Key" : "gs:account", "Value" : "${accountId}" },
					  { "Key" : "gs:project", "Value" : "${projectId}" },
					  { "Key" : "gs:container", "Value" : "${containerId}" },
					  { "Key" : "gs:environment", "Value" : "${environmentId}" },
					  { "Key" : "gs:category", "Value" : "${categoryId}" },
					  { "Key" : "gs:tier", "Value" : "${tier.Id}" },
					  { "Key" : "gs:zone", "Value" : "${zone.Id}" },
					  [#if routeTable.Private!false]
						{ "Key" : "network", "Value" : "private" },
					  [/#if]
					  { "Key" : "Name", "Value" : "${projectName}-${containerName}-${tier.Name}-${zone.Name}" } 
					]
				  }
				},
	
				"routeTableXassociationX${tier.Id}X${zone.Id}" : 
				{
				  "Type" : "AWS::EC2::SubnetRouteTableAssociation",
				  "Properties" : 
				  {
					"SubnetId" : { "Ref" : "subnetX${tier.Id}X${zone.Id}" },
					"RouteTableId" : { "Ref" : "routeTableX${routeTable.Id + jumpServerPerAZ?string("X" + zone.Id,"")}" }
				  }
				},
	
				"networkACLXassociationX${tier.Id}X${zone.Id}" : 
				{
				  "Type" : "AWS::EC2::SubnetNetworkAclAssociation",
				  "Properties" : 
				  {
					"SubnetId" : { "Ref" : "subnetX${tier.Id}X${zone.Id}" },
					"NetworkAclId" : { "Ref" : "networkACLX${networkACL.Id}" }
				  }
				}
			[/#list]
		[/#list]
  
	  [#if jumpServer]
		[#assign tier = tiers["mgmt"]]
		,"roleX${tier.Id}Xnat": {
		  "Type" : "AWS::IAM::Role",
		  "Properties" : {
			"AssumeRolePolicyDocument" : {
			  "Version": "2012-10-17",
			  "Statement": [ {
				"Effect": "Allow",
				"Principal": { "Service": [ "ec2.amazonaws.com" ] },
				"Action": [ "sts:AssumeRole" ]
			  } ]
			},
			"Path": "/",
			"Policies": [
			  {
				"PolicyName": "${tier.Id}-nat",
				"PolicyDocument" : {
				  "Version": "2012-10-17",
				  "Statement": 
				  [
					{
					  "Effect" : "Allow",
					  "Action" : [
						"ec2:DescribeInstances",
						"ec2:ModifyInstanceAttribute",
						"ec2:DescribeSubnets",
						"ec2:DescribeRouteTables",
						"ec2:CreateRoute",
						"ec2:ReplaceRoute",
						"ec2:DescribeAddresses",
						"ec2:AssociateAddress"
					  ],
					  "Resource": "*"
					},
					{
						"Resource": [
							"arn:aws:s3:::${codeBucket}"
						],
						"Action": [
							"s3:ListBucket"
						],
						"Effect": "Allow"
					},
					{
						"Resource": [
							"arn:aws:s3:::${codeBucket}/*"
						],
						"Action": [
							"s3:GetObject",
							"s3:ListObjects"
						],
						"Effect": "Allow"
					}
				  ]
				}
			  }
			]
		  }
		},
		"instanceProfileX${tier.Id}Xnat" : {
		  "Type" : "AWS::IAM::InstanceProfile",
		  "Properties" : {
			"Path" : "/",
			"Roles" : [ { "Ref" : "roleX${tier.Id}Xnat" } ]
		  }
		},
		"securityGroupX${tier.Id}Xnat" : {
		  "Type" : "AWS::EC2::SecurityGroup",
		  "Properties" : {
			"GroupDescription": "Security Group for HA NAT instances",
			"VpcId": { "Ref": "vpc" },
			"Tags" : [
				{ "Key" : "gs:account", "Value" : "${accountId}" },
				{ "Key" : "gs:project", "Value" : "${projectId}" },
				{ "Key" : "gs:container", "Value" : "${containerId}" },
				{ "Key" : "gs:environment", "Value" : "${environmentId}" },
				{ "Key" : "gs:category", "Value" : "${categoryId}" },
				{ "Key" : "gs:tier", "Value" : "${tier.Id}"},
				{ "Key" : "gs:component", "Value" : "nat"},
				{ "Key" : "Name", "Value" : "${projectName}-${containerName}-${tier.Name}-nat" }
			],
			"SecurityGroupIngress" : [
					{ "IpProtocol": "tcp", "FromPort": "22", "ToPort": "22", "CidrIp": "0.0.0.0/0" },
					{ "IpProtocol": "-1", "FromPort": "1", "ToPort": "65535", "CidrIp": "${bClass}.0.0/16" }
			]
		  }
		},
		"securityGroupX${tier.Id}XallXnat" : {
		  "Type" : "AWS::EC2::SecurityGroup",
		  "Properties" : {
			"GroupDescription": "Security Group for access from NAT",
			"VpcId": { "Ref": "vpc" },
			"Tags" : [
				{ "Key" : "gs:account", "Value" : "${accountId}" },
				{ "Key" : "gs:project", "Value" : "${projectId}" },
				{ "Key" : "gs:container", "Value" : "${containerId}" },
				{ "Key" : "gs:environment", "Value" : "${environmentId}" },
				{ "Key" : "gs:category", "Value" : "${categoryId}" },
				{ "Key" : "gs:tier", "Value" : "all"},
				{ "Key" : "gs:component", "Value" : "nat"},
				{ "Key" : "Name", "Value" : "${projectName}-${containerName}-all-nat" }
			],
			"SecurityGroupIngress" : [
					{ "IpProtocol": "tcp", "FromPort": "22", "ToPort": "22", "SourceSecurityGroupId": { "Ref" : "securityGroupX${tier.Id}Xnat"} }
			]
		  }
		}
	
		[#assign solutionNATInstances = []]
		[#list regionObject.Zones as zone]
			[#if jumpServerPerAZ || firstZone.Id = zone.Id]
				,"asgX${tier.Id}XnatX${zone.Id}": {
				  "DependsOn" : [ "subnetX${tier.Id}X${zone.Id}" ],
				  "Type": "AWS::AutoScaling::AutoScalingGroup",
				  "Metadata": {
					"AWS::CloudFormation::Init": {
					  "configSets" : {
						"nat" : ["dirs", "bootstrap", "nat"]
					  },
					  "dirs": {
						"commands": {
						  "01Directories" : {
							"command" : "mkdir --parents --mode=0755 /etc/gosource && mkdir --parents --mode=0755 /opt/gosource/bootstrap && mkdir --parents --mode=0755 /var/log/gosource",
							"ignoreErrors" : "false"
						  }
						}
					  },
					  "bootstrap": {		  
						"packages" : {
							"yum" : {
								"aws-cli" : []
							}
						},  
						"files" : {
						  "/etc/gosource/facts.sh" : {
							"content" : { "Fn::Join" : ["", [
									"#!/bin/bash\n",
									"echo \"gs:accountRegion=${accountRegionId}\"\n",
									"echo \"gs:account=${accountId}\"\n",
									"echo \"gs:project=${projectId}\"\n",
									"echo \"gs:region=${regionId}\"\n",
									"echo \"gs:container=${containerId}\"\n",
									"echo \"gs:environment=${environmentId}\"\n",
									"echo \"gs:tier=${tier.Id}\"\n",
									"echo \"gs:component=nat\"\n",
									"echo \"gs:zone=${zone.Id}\"\n",
									"echo \"gs:role=nat\"\n",
									"echo \"gs:credentials=${credentialsBucket}\"\n",
									"echo \"gs:code=${codeBucket}\"\n",
									"echo \"gs:configuration=${configurationBucket}\"\n",
									"echo \"gs:logs=${logsBucket}\"\n",
									"echo \"gs:backups=${backupsBucket}\"\n"
								]]
							},
							"mode" : "000755"
						  },
						  "/opt/gosource/bootstrap/fetch.sh" : {
							"content" : { "Fn::Join" : ["", [
									"#!/bin/bash -ex\n",
									"exec > >(tee /var/log/gosource/fetch.log|logger -t gosource-fetch -s 2>/dev/console) 2>&1\n",
									"REGION=$(/etc/gosource/facts.sh | grep gs:accountRegion | cut -d '=' -f 2)\n",
									"CODE=$(/etc/gosource/facts.sh | grep gs:code | cut -d '=' -f 2)\n",
									"aws --region ${r"${REGION}"} s3 sync s3://${r"${CODE}"}/bootstrap/centos/ /opt/gosource/bootstrap && chmod 0500 /opt/gosource/bootstrap/*.sh\n"
								]]
							},
							"mode" : "000755"
						  }		  	  
						},
						"commands": {
						  "01Fetch" : {
							"command" : "/opt/gosource/bootstrap/fetch.sh",
							"ignoreErrors" : "false"
						  },
						  "02Initialise" : {
							"command" : "/opt/gosource/bootstrap/init.sh",
							"ignoreErrors" : "false"
						  }
						}
					  },
					  "nat": {
						"commands": {
						  "01ExecuteRouteUpdateScript" : {
							"command" : "/opt/gosource/bootstrap/nat.sh",
							"ignoreErrors" : "false"
						  },
 						  "02ExecuteAllocateEIPScript" : {
							"command" : "/opt/gosource/bootstrap/eip.sh",
							"env" : { 
							    [#if slice?? && slice?contains("eip")]
							        [#-- Legacy code to support definition of eip and vpc in one template --]
    							    "EIP_ALLOCID" : { "Fn::GetAtt" : ["eipX${tier.Id}XnatX${zone.Id}", "AllocationId"] }
							    [#else]
							        [#-- Normally assume eip defined in a separate template to the vpc --]
     							    "EIP_ALLOCID" : "${getKey("eipX" + tier.Id + "XnatX" + zone.Id + "Xid")}"
                               [/#if]
							},
							"ignoreErrors" : "false"
						  }
						}
					  }
					}
				  },
				  "Properties": {
					"Cooldown" : "30",
					"LaunchConfigurationName": {"Ref": "launchConfigX${tier.Id}XnatX${zone.Id}"},
					"MinSize": "1",
					"MaxSize": "1",
					"VPCZoneIdentifier": [ { "Ref" : "subnetX${tier.Id}X${zone.Id}"} ],
					"Tags" : [
						{ "Key" : "gs:account", "Value" : "${accountId}", "PropagateAtLaunch" : "True" },
						{ "Key" : "gs:project", "Value" : "${projectId}", "PropagateAtLaunch" : "True" },
						{ "Key" : "gs:container", "Value" : "${containerId}", "PropagateAtLaunch" : "True" },
						{ "Key" : "gs:environment", "Value" : "${environmentId}", "PropagateAtLaunch" : "True" },
						{ "Key" : "gs:category", "Value" : "${categoryId}", "PropagateAtLaunch" : "True" },
						{ "Key" : "gs:tier", "Value" : "${tier.Id}", "PropagateAtLaunch" : "True" },
						{ "Key" : "gs:component", "Value" : "nat", "PropagateAtLaunch" : "True"},
						{ "Key" : "gs:zone", "Value" : "${zone.Id}", "PropagateAtLaunch" : "True" },
						{ "Key" : "Name", "Value" : "${projectName}-${containerName}-${tier.Name}-nat-${zone.Name}", "PropagateAtLaunch" : "True" }
					]
				  }
				},
			
				[#assign component = { "Id" : ""}]
				[#assign processorProfile = getProcessor(tier, component, "NAT")]
				"launchConfigX${tier.Id}XnatX${zone.Id}": {
				  "Type": "AWS::AutoScaling::LaunchConfiguration",
				  "Properties": {
					"KeyName": "${projectName + sshPerContainer?string("-" + containerName,"")}",
					"ImageId": "${regionObject.AMIs.Centos.NAT}",
					"InstanceType": "${processorProfile.Processor}",
					"SecurityGroups" : [ { "Ref": "securityGroupX${tier.Id}Xnat" } ],
					"IamInstanceProfile" : { "Ref" : "instanceProfileX${tier.Id}Xnat" },
					"AssociatePublicIpAddress": true,
					"UserData": {
					  "Fn::Base64": { "Fn::Join": [ "", [
						"#!/bin/bash -ex\n",
						"exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1\n",
						"yum install -y aws-cfn-bootstrap\n",				  
						"# Remainder of configuration via metadata\n",
						"/opt/aws/bin/cfn-init -v",
						"         --stack ", { "Ref" : "AWS::StackName" },
						"         --resource asgX${tier.Id}XnatX${zone.Id}",
						"         --region ${regionId} --configsets nat\n"
					  ] ] }
					}
				  }
				}
			[/#if]
		[/#list]
	  [/#if]
      [#assign sliceCount = sliceCount + 1]
	[/#if]
  
	[#if !(slice??) || (slice?contains("s3"))]
		[#-- Create logs bucket --]
		[#if sliceCount > 0],[/#if]"s3Xlogs" : {
			"Type" : "AWS::S3::Bucket",
			"Properties" : {
				"BucketName" : "${logsBucket}",
				"Tags" : [ 
					{ "Key" : "gs:project", "Value" : "${projectId}" },
					{ "Key" : "gs:container", "Value" : "${containerId}" },
					{ "Key" : "gs:environment", "Value" : "${environmentId}" },
					{ "Key" : "gs:category", "Value" : "${categoryId}" }
				],
				"LifecycleConfiguration" : {
				    "Rules" : [
				        {
				            "Id" : "default",
				            "ExpirationInDays" : ${logsExpiration},
				            "Status" : "Enabled"
				        }
				    ]
				}
			}
		},
		[#-- Ensure ELBs can write to the logs bucket --]
		"s3XlogsXpolicy" : {
			"Type" : "AWS::S3::BucketPolicy",
			"Properties" : {
				"Bucket" : "${logsBucket}",
				"PolicyDocument" : {
					"Statement": [
						{
							"Effect": "Allow",
							"Principal": {
								"AWS": "arn:aws:iam::${regionObject.Accounts["ELB"]}:root"
							},
							"Action": "s3:PutObject",
							"Resource": "arn:aws:s3:::${logsBucket}/AWSLogs/*"
						}
					]
				}				
			}
		},
		[#-- Create backups bucket --]
		"s3Xbackups" : {
			"Type" : "AWS::S3::Bucket",
			"Properties" : {
				"BucketName" : "${backupsBucket}",
				"Tags" : [ 
					{ "Key" : "gs:project", "Value" : "${projectId}" },
					{ "Key" : "gs:container", "Value" : "${containerId}" },
					{ "Key" : "gs:environment", "Value" : "${environmentId}" },
					{ "Key" : "gs:category", "Value" : "${categoryId}" }
				],
				"LifecycleConfiguration" : {
				    "Rules" : [
				        {
				            "Id" : "default",
				            "ExpirationInDays" : ${backupsExpiration},
				            "Status" : "Enabled"
				        }
				    ]
				}
			}
		}
        [#assign sliceCount = sliceCount + 1]
	[/#if]
  },

  "Outputs" : 
  {
    [#assign sliceCount = 0]
	[#if !(slice??) || (slice?contains("eip"))]
		[#-- Define EIPs --]
		[#assign eipCount = 0]
        [#if jumpServer]
		    [#assign tier = tiers["mgmt"]]
		    [#list regionObject.Zones as zone]
			    [#if jumpServerPerAZ || firstZone.Id = zone.Id]
			        [#if eipCount > 0],[/#if]
					"eipX${tier.Id}XnatX${zone.Id}Xip": {
						"Value" : { "Ref" : "eipX${tier.Id}XnatX${zone.Id}" }
					},
					"eipX${tier.Id}XnatX${zone.Id}Xid": {
						"Value" : { "Fn::GetAtt" : ["eipX${tier.Id}XnatX${zone.Id}", "AllocationId"] }
					}
				    [#assign eipCount = eipCount + 1]
				[/#if]
		    [/#list]
            [#assign sliceCount = sliceCount + 1]
		[/#if]
    [/#if]
	[#if !(slice??) || (slice?contains("vpc"))]
		[#if sliceCount > 0],[/#if]"vpcXcontainerXvpc" : 
		{
		  "Value" : { "Ref" : "vpc" }
		},
		"igwXcontainerXigw" : 
		{
		  "Value" : { "Ref" : "igw" }
		}
		[#if jumpServer]
			[#assign tier = tiers["mgmt"]]
			,"securityGroupXmgmtXnat" : 
			{
				"Value" : { "Ref" : "securityGroupX${tier.Id}XallXnat" }
			}
		[/#if]
		[#list solutionTiers as solutionTier]
			[#assign tier = tiers[solutionTier.Id]]
			[#list regionObject.Zones as zone]
				,"subnetX${tier.Id}X${zone.Id}" : 
				{
				  "Value" : { "Ref" : "subnetX${tier.Id}X${zone.Id}" }
				}
			[/#list]
		[/#list]
        [#assign sliceCount = sliceCount + 1]
    [/#if]
	[#if !(slice??) || (slice?contains("s3"))]
		[#if sliceCount > 0],[/#if]"s3XcontainerXlogs" : 
		{
		  "Value" : { "Ref" : "s3Xlogs" }
		},
		"s3XcontainerXbackups" : 
		{
		  "Value" : { "Ref" : "s3Xbackups" }
		}
        [#assign sliceCount = sliceCount + 1]
	[/#if]
  }
}






