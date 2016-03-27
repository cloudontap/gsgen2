[#ftl]
{
	"Profile" : {
		"Type" : "Solution",
		"Schema" : {
			"Name" : "Solution",
			"MinimumVersion" : {
				"Major" : 1
			}
		},
		"Title" : "Basic network to enable launching of alpha stage project systems",
		"Version" :	{
				"Major" : 1,
				"Minor" : 0
		}
	},
	
	"Solution" : {
		"Title" : "Basic network to enable launching of alpha stage project systems",
		"Id" : "alpha",
		"Name" : "alpha",
		[#if region??]
		"Region" : "${region}",
		[/#if]
		"SSHPerContainer" : true,
		"Container" : {
			"BClass" : "10.0",
			"InternetAccess" : true,
			"DNSSupport" : true,
			"DNSHostnames" : false
		},
		"CapacityProfile" : "default",
		"Tiers" : [
			{
				"Id" : "web",
				"RouteTable" : "external"
			}
		]
	}
}
