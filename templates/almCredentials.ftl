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
		"alm" : {
			"LDAP" : {
				"UserDN" : "uid=alm@${accountId}.gosource.com.au,dc=gosource,dc=com,dc=au",
				"Password" : "${ldapPassword}"
			},
			"Bind" : {
				"BindDN" : "cn=alm,ou=${accountId},ou=accounts,ou=${organisationId},ou=organisations,dc=gosource,dc=com,dc=au",
				"Password" : "${bindPassword}"
			}
		}
	}
}
