from os import system
import pyodbc
import json
import jsonschema
import util

# Load settings
# TODO: schema validation
file = open('config.json')
settings = json.load(file)
email = settings["email_account"]
recepients = settings["email_recepients"]

# Initiate connection
conn_str = f'DSN={settings["dsn"]};Trusted_Connection=yes;'
conn = pyodbc.connect(conn_str)
cursor = conn.cursor()

# Install email account
email_acc_query = (
    f"EXECUTE msdb.dbo.sysmail_add_account_sp "
    f"@account_name = '{email['account_name']}', " 
    f"@description = '{email['description']}', " 
    f"@email_address = '{email['email_address']}', "  
    f"@display_name = '{email['display_name']}', "
    f"@mailserver_name = '{email['smtp_address']}', "
    f"@username = '{email['smtp_username']}', "
    f"@password = '{email['smtp_password']}' ;"
) 

try:
    cursor.execute(email_acc_query)
except Exception as e:
    if "SYSMAIL_ACCOUNT_NameMustBeUnique" in str(e):
        print("Email account already exists, continuing execution.")
        print("==========")

# SQL setup
setup_queries = util.parseSqlFile("EmailerSetup.sql")
for setup_query in setup_queries:
    try:
        cursor.execute(setup_query)
    except Exception as e:
        if "42S01" in str(e):
            print("Table already exists, continuing excecution.")
            print("Details:")
            print(e)
            print("==========")
        else:
            print("Fatal SQL error detected. Exiting program.")
            print("Details:")
            print(e)
            system.exit(1)


# Add email recepients
cursor.execute("DELETE FROM Emailer.EmailListRecipients;")
recepient_insert_query = """
    INSERT [Emailer].[EmailListRecipients] ([EventType], [RecipientList], [LastStatusTypeLike], [EmailProfileName], [EmailTemplate], [DateAdd]) 
    VALUES (N'%s', N'%s', N'%s', N'%s', N'%s', N'%s')
"""

for recepient in recepients:
    email_template = util.parseHtmlFile(recepient["email_template"])
    constructed_query = recepient_insert_query % (
        recepient["event_type"],
        recepient["recepient_list"],
        recepient["last_status_type_like"],
        recepient["email_profile_name"],
        email_template,
        recepient["date_add"]
    )
    cursor.execute(constructed_query)

conn.commit()
conn.close()