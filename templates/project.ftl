[#ftl]
{
	"Profile" : {
		"Type" : "Project",
		"Schema" : {
			"Name" : "Project",
			"MinimumVersion" : {
				"Major" : 1
			}
		},
		"Title" : "${project}",
		[#if Description??]
		"Description" : "${description}",
		[/#if]
		"Version" :	{
			"Major" : 1,
			"Minor" : 0
		}
	},
	
	"Project" : {
		"Title" : "${project}",
		"Id" : "${id}",
		"Name" : "${name}"
		[#if Description??],
		"Description" : "${description}"
		[/#if]
	}
}
