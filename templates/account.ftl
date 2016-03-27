[#ftl]
{
	"Profile" : {
		"Type" : "Account",
		"Schema" : {
			"Name" : "Account",
			"MinimumVersion" : {
				"Major" : 1
			}
		},
		"Title" : "${account}",
		[#if Description??]
		"Description" : "${description}",
		[/#if]
		"Version" :	{
			"Major" : 1,
			"Minor" : 0
		}
	},
	
	"Account" : {
		"Title" : "${account}",
		"Id" : "${id}",
		"Name" : "${name}",
		[#if Description??]
		"Description" : "${description}",
		[/#if]
		"Region" : "${region}",
		"SESRegion" : "${sesRegion}"
	}
}
