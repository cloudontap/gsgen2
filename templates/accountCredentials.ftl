[#ftl]
{
	"Profile" : {
		"Type" : "Credentials",
		"Schema" : {
			"Name" : "Credentials",
			"MinimumVersion" : {
				"Major" : 1
			}
		},
		"Title" : "Credentials used by a project/account",
		"Description" : "Storing as JSON allows credentials to be integrated as part of deployments",
		"Version" :	{
				"Major" : 1,
				"Minor" : 0
		}
	},
	
	"Credentials" : {
		"gosource-root" : {
			"Login" : {
				"Username" : "gosource-root",
				"Password" : "${password}"
			},
			"API" : {
				"AccessKey" : "?",
				"SecretKey" : "?"
			}
		},
		"gosource-ses" : {
			"SMTP" : {
				"Username" : "gosource-ses",
				"SMTPUsername" : "?",
				"Password" : "?",
				"Region" : "us-west-2"
			}
		}
	}
}
