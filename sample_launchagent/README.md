# Privileges.app LaunchAgent

This sample LaunchAgent for **Privileges.app** can be used to automatically remove admin rights on login. To do this, it uses the `PrivilegesCLI` command line tool to run the following command:

`/Applications/Privileges.app/Contents/Resources/PrivilegesCLI --remove`

Running this command removes the logged-in user from the admin group.

## Support

This project is 'as-is' with no support, no changes being made.  You are welcome to make changes to improve it but we are not available for questions or support of any kind.
