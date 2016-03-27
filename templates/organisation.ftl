[#ftl]
{
	"Profile" : {
		"Type" : "Organisation",
		"Schema" : {
			"Name" : "Organisation",
			"MinimumVersion" : {
				"Major" : 1
			}
		},
		"Title" : "${organisation}",
		[#if Description??]
		"Description" : "${description}",
		[/#if]
		"Version" :	{
			"Major" : 1,
			"Minor" : 0
		}
	},
	
	"Organisation" : {
		"Title" : "${organisation}",
		"Id" : "${id}",
		"Name" : "${name}"
		[#if Description??],
		"Description" : "${description}"
		[/#if]
	}
}
