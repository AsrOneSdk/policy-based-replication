### -----------------------------------------------------------------------------------------------
### <script name=policy-surveillance>
### <summary>
### This script helps monitor the VMs in the source resource group. It consolidates all possible
### issues (validation, deployment/protection, replication health) and provides a single portal to
### view them all.
### </summary>
###
### <param name="subscriptionId">Mandatory parameter defining the subscription Id.</param>
### <param name="sourceResourceGroupName">Mandatory parameter defining the source resource group
### name. The policy will be deployed at this resource group's scope.</param>
### <param name="logFileLocation">Optional parameter defining the script log file location. Default
### value used - script file location.</param>
### <param name="EnableLog">Switch parameter indicating if logs need to be enabled.</param>
### <param name="EnableGUI">Switch parameter indicating whether GUI need to be enabled.</param>
### -----------------------------------------------------------------------------------------------

#Region Parameters

[CmdletBinding()]
param(
    [Parameter(
        Mandatory = $true,
        HelpMessage = "Subscription Id.")]
    [ValidateNotNullorEmpty()]
    [string]$subscriptionId,

    [Parameter(
        Mandatory = $true,
        HelpMessage = "Source resource group name.")]
    [ValidateNotNullorEmpty()]
    [string]$sourceResourceGroupName,

    [Parameter(
        Mandatory = $false,
        HelpMessage = "Script logs location. Default location would be that of the " + `
            "script file run.")]
    [ValidateNotNullorEmpty()]
    [string]$logFileLocation = $null,

    [Parameter(
        Mandatory = $false,
        HelpMessage = "Switch parameter indicating whether logs need to be enabled.")]
    [switch]$enableLog = $false,

    [Parameter(
        Mandatory = $false,
        HelpMessage = "Switch parameter indicating whether GUI need to be enabled.")]
    [switch]$enableGUI = $false)
#EndRegion

#Region Required

#Requires -Modules "Az.Compute"
#Requires -Modules "Az.RecoveryServices"
#Requires -Modules "Az.Resources"
Set-StrictMode -Version 1.0
Add-Type -AssemblyName System.Windows.Forms
[System.Windows.Forms.Application]::EnableVisualStyles()
#EndRegion

#Region GUI

### <summary>
###  Names of the grid view columns.
### </summary>
Enum GridViewColumnName
{
    ### <summary>
    ###  Column name is VirtualMachine.
    ### </summary>
    VirtualMachine = 0

    ### <summary>
    ###  Column name is ProtectionState.
    ### </summary>
    ProtectionState = 1

    ### <summary>
    ###  Column name is ReplicationHealth.
    ### </summary>
    ReplicationHealth = 2

    ### <summary>
    ###  Column name is ReplicationProtectedItem.
    ### </summary>
    ReplicationProtectedItem = 3

    ### <summary>
    ###  Column name is AsrDeployment.
    ### </summary>
    AsrDeployment = 4

    ### <summary>
    ###  Column name is DeploymentState.
    ### </summary>
    DeploymentState = 5

    ### <summary>
    ###  Column name is Errors.
    ### </summary>
    Errors = 6
}

### <summary>
### Class to maintain all the GUI aspects.
### </summary>
Class UserInterface
{
    ### <summary>
    ### Gets the form to be displayed.
    ### </summary>
    [System.Windows.Forms.Form] $PolicyForm

    ### <summary>
    ### Gets the form to be displayed.
    ### </summary>
    [System.Windows.Forms.DataGridView] $VmInfoGridView

    ### <summary>
    ### Initializes an instance of UserInterface and forms a predesigned form.
    ### </summary>
    ### <param name="subscriptionId">Subscription id.</param>
    ### <param name="resourceGroupName">Resource group name.</param>
    ### <param name="policyAssignment">Policy assignment.</param>
    UserInterface($subscriptionId, $resourceGroupName, $policyAssignment)
    {
        #Region Prereq

        $complianceDetailedBladeScope = '["/' + [ConstantStrings]::subscriptions + '/' + `
            $subscriptionId + '"]'
        $assignmentCompliancePage =
            [ConstantStrings]::portalPolicyDetailedComplianceBladePrefix + `
            [uri]::EscapeDataString($policyAssignment.ResourceId) + "/" + `
            [ConstantStrings]::scopes + "/" + [uri]::EscapeDataString($complianceDetailedBladeScope)
        $newRemediationTaskPage =
            [ConstantStrings]::portalPolicyCreateRemediationTaskBladePrefix + `
            [uri]::EscapeDataString($policyAssignment.ResourceId) + "/" + `
            [ConstantStrings]::scopes + "/" + [uri]::EscapeDataString($complianceDetailedBladeScope)

        $policyAssignmentSummary = Get-PolicyAssignmentSummary -PolicyAssignment $policyAssignment
        #EndRegion

        #Region Form - Setup

        $this.PolicyForm                 = [System.Windows.Forms.Form]::New()
        $this.PolicyForm.ClientSize      = '1000,400'
        $this.PolicyForm.text            = "Policy Surveillance"
        $this.PolicyForm.BackColor       = "#d6e6f5"
        #EndRegion

        #Region MsLogo (Not in use)

        $MsLogo = [System.Windows.Forms.PictureBox]::New()
        $MsLogo.width         = 140
        $MsLogo.height        = 80
        $MsLogo.location      = [System.Drawing.Point]::New(745, 20)
        $MsLogo.imageLocation = [ConstantStrings]::microsoftLogoLink
        $MsLogo.SizeMode      = [System.Windows.Forms.PictureBoxSizeMode]::zoom
        #EndRegion

        #Region Subscription

        $SubscriptionIdLabel             = [System.Windows.Forms.Label]::New()
        $SubscriptionIdLabel.text        = "SubscriptionId: "
        $SubscriptionIdLabel.AutoSize    = $true
        $SubscriptionIdLabel.width       = 100
        $SubscriptionIdLabel.height      = 12
        $SubscriptionIdLabel.location    = [System.Drawing.Point]::New(15,20)
        $SubscriptionIdLabel.Font        = 'style=Bold'
        $SubscriptionIdLabel.ForeColor   = "#143855"

        $SubscriptionIdValueLabel           = [System.Windows.Forms.Label]::New()
        $SubscriptionIdValueLabel.text      = $subscriptionId
        $SubscriptionIdValueLabel.AutoSize  = $true
        $SubscriptionIdValueLabel.width     = 100
        $SubscriptionIdValueLabel.height    = 12
        $SubscriptionIdValueLabel.location  = [System.Drawing.Point]::New(160,20)
        $SubscriptionIdValueLabel.ForeColor = "#143855"
        #EndRegion

        #Region Github issue

        $GithubIssueLinkLabel                 = [System.Windows.Forms.LinkLabel]::New()
        $GithubIssueLinkLabel.text            = "Raise Bug"
        $GithubIssueLinkLabel.LinkColor       = [System.Drawing.Color]::DarkBlue
        $GithubIssueLinkLabel.ActiveLinkColor = [System.Drawing.Color]::DarkMagenta
        $GithubIssueLinkLabel.AutoSize        = $true
        $GithubIssueLinkLabel.width           = 100
        $GithubIssueLinkLabel.height          = 12
        $GithubIssueLinkLabel.location        = [System.Drawing.Point]::New(900,20)
        $GithubIssueLinkLabel.Font            = 'style=Underline'
        $GithubIssueLinkLabel.ForeColor       = "#143855"
        $GithubIssueLinkLabel.Links.Add(
            0,
            $GithubIssueLinkLabel.text.Length,
            [ConstantStrings]::githubIssue)
        $GithubIssueLinkLabel.add_Click(
            {
                [System.Diagnostics.Process]::Start($this.Links[0].LinkData)
            })
        #EndRegion

        #Region Resource group

        $ResourceGroupNameLabel           = [System.Windows.Forms.Label]::New()
        $ResourceGroupNameLabel.text      = "ResourceGroupName: "
        $ResourceGroupNameLabel.AutoSize  = $true
        $ResourceGroupNameLabel.width     = 100
        $ResourceGroupNameLabel.height    = 12
        $ResourceGroupNameLabel.location  = [System.Drawing.Point]::New(15, 40)
        $ResourceGroupNameLabel.Font      = 'style=Bold'
        $ResourceGroupNameLabel.ForeColor = "#143855"

        $ResourceGroupNameValueLabel           = [System.Windows.Forms.Label]::New()
        $ResourceGroupNameValueLabel.text      = $resourceGroupName
        $ResourceGroupNameValueLabel.AutoSize  = $true
        $ResourceGroupNameValueLabel.width     = 100
        $ResourceGroupNameValueLabel.height    = 12
        $ResourceGroupNameValueLabel.location  = [System.Drawing.Point]::New(160, 40)
        $ResourceGroupNameValueLabel.ForeColor = "#143855"
        #EndRegion

        #Region Policy Assignment

        $PolicyAssignmentLabel           = [System.Windows.Forms.Label]::New()
        $PolicyAssignmentLabel.text      = "PolicyAssignment: "
        $PolicyAssignmentLabel.AutoSize  = $true
        $PolicyAssignmentLabel.width     = 100
        $PolicyAssignmentLabel.height    = 12
        $PolicyAssignmentLabel.location  = [System.Drawing.Point]::New(15, 60)
        $PolicyAssignmentLabel.Font      = 'style=Bold'
        $PolicyAssignmentLabel.ForeColor = "#143855"

        $PolicyAssignmentLinkLabel                 = [System.Windows.Forms.LinkLabel]::New()
        $PolicyAssignmentLinkLabel.text            = $policyAssignment.Name
        $PolicyAssignmentLinkLabel.LinkColor       = [System.Drawing.Color]::DarkBlue
        $PolicyAssignmentLinkLabel.ActiveLinkColor = [System.Drawing.Color]::DarkMagenta
        $PolicyAssignmentLinkLabel.AutoSize        = $true
        $PolicyAssignmentLinkLabel.width           = 100
        $PolicyAssignmentLinkLabel.height          = 12
        $PolicyAssignmentLinkLabel.location        = [System.Drawing.Point]::New(160, 60)
        $PolicyAssignmentLinkLabel.Font            = 'style=Underline'
        $PolicyAssignmentLinkLabel.ForeColor       = "#143855"
        $PolicyAssignmentLinkLabel.Links.Add(
            0,
            $PolicyAssignmentLinkLabel.text.Length,
            $assignmentCompliancePage)
        $PolicyAssignmentLinkLabel.add_Click(
            {
                [System.Diagnostics.Process]::Start($this.Links[0].LinkData)
            })
        #EndRegion

        #Region Policy Assignment Summary - non-compliant resources

        $NonCompliantResourcesLabel           = [System.Windows.Forms.Label]::New()
        $NonCompliantResourcesLabel.text      = "Non-Compliant Resources: "
        $NonCompliantResourcesLabel.AutoSize  = $true
        $NonCompliantResourcesLabel.width     = 100
        $NonCompliantResourcesLabel.height    = 12
        $NonCompliantResourcesLabel.location  = [System.Drawing.Point]::New(15, 80)
        $NonCompliantResourcesLabel.Font      = 'style=Bold'
        $NonCompliantResourcesLabel.ForeColor = "#143855"

        $NonCompliantResourcesValueLabel           = [System.Windows.Forms.Label]::New()
        $NonCompliantResourcesValueLabel.text      =
            $policyAssignmentSummary.Results.NonCompliantResources
        $NonCompliantResourcesValueLabel.AutoSize  = $true
        $NonCompliantResourcesValueLabel.width     = 100
        $NonCompliantResourcesValueLabel.height    = 12
        $NonCompliantResourcesValueLabel.location  = [System.Drawing.Point]::New(160, 80)
        $NonCompliantResourcesValueLabel.ForeColor = "#143855"
        #EndRegion

        #Region Policy Remediation

        $PolicyRemediationLabel           = [System.Windows.Forms.Label]::New()
        $PolicyRemediationLabel.text      = "Policy Remediation: "
        $PolicyRemediationLabel.AutoSize  = $true
        $PolicyRemediationLabel.width     = 100
        $PolicyRemediationLabel.height    = 12
        $PolicyRemediationLabel.location  = [System.Drawing.Point]::New(15, 100)
        $PolicyRemediationLabel.Font      = 'style=Bold'
        $PolicyRemediationLabel.ForeColor = "#143855"

        $PolicyRemediationLinkLabel                 = [System.Windows.Forms.LinkLabel]::New()
        $PolicyRemediationLinkLabel.text            = "Create Remediation Task"
        $PolicyRemediationLinkLabel.LinkColor       = [System.Drawing.Color]::DarkBlue
        $PolicyRemediationLinkLabel.ActiveLinkColor = [System.Drawing.Color]::DarkMagenta
        $PolicyRemediationLinkLabel.AutoSize        = $true
        $PolicyRemediationLinkLabel.width           = 100
        $PolicyRemediationLinkLabel.height          = 12
        $PolicyRemediationLinkLabel.location        = [System.Drawing.Point]::New(160, 100)
        $PolicyRemediationLinkLabel.Font            = 'style=Underline'
        $PolicyRemediationLinkLabel.ForeColor       = "#143855"
        $PolicyRemediationLinkLabel.Links.Add(
            0,
            $PolicyRemediationLinkLabel.text.Length,
            $newRemediationTaskPage)
        $PolicyRemediationLinkLabel.add_Click(
            {
                [System.Diagnostics.Process]::Start($this.Links[0].LinkData)
            })
        #EndRegion

        #Region VM Info GridView

        $this.VmInfoGridView                      = [System.Windows.Forms.DataGridView]::New()
        $this.VmInfoGridView.width                = 1000
        $this.VmInfoGridView.height               = 250
        $this.VmInfoGridView.ColumnHeadersVisible = $true
        $this.VmInfoGridView.AllowUserToAddRows   = $false

        #Region Grid Columns

        $this.VmInfoGridView.ColumnCount      = 7
        $this.VmInfoGridView.Columns[0].Name  = [GridViewColumnName]::VirtualMachine.ToString()
        $this.VmInfoGridView.Columns[0].Width = 150

        $this.VmInfoGridView.Columns[1].Name  = [GridViewColumnName]::ProtectionState.ToString()
        $this.VmInfoGridView.Columns[1].Width = 125

        $this.VmInfoGridView.Columns[2].Name  = [GridViewColumnName]::ReplicationHealth.ToString()
        $this.VmInfoGridView.Columns[2].Width = 100

        $this.VmInfoGridView.Columns[3].Name  =
            [GridViewColumnName]::ReplicationProtectedItem.ToString()
        $this.VmInfoGridView.Columns[3].Width = 225

        $this.VmInfoGridView.Columns[4].Name  = [GridViewColumnName]::AsrDeployment.ToString()
        $this.VmInfoGridView.Columns[4].Width = 150

        $this.VmInfoGridView.Columns[5].Name  = [GridViewColumnName]::DeploymentState.ToString()
        $this.VmInfoGridView.Columns[5].Width = 100

        $this.VmInfoGridView.Columns[6].Name  = [GridViewColumnName]::Errors.ToString()
        $this.VmInfoGridView.Columns[6].Width = 100
        #EndRegion

        $this.VmInfoGridView.Anchor           = 'bottom,left'
        $this.VmInfoGridView.location         = [System.Drawing.Point]::New(0, 150)

        $this.VmInfoGridView.Add_CellClick(
            {

                $value = $this.Rows[$_.RowIndex].Cells[$_.ColumnIndex].ToolTipText

                # Error popup
                if ($_.ColumnIndex -ne [GridViewColumnName]::Errors)
                {
                    return
                }

                if ([string]::IsNullOrEmpty($value))
                {
                    return
                }

                $popUpForm              = [System.Windows.Forms.Form]::New()
                $popUpForm.ClientSize   = "300,300"
                $popUpForm.text         = "Errors"
                $popUpForm.BackColor    = "#d6e6f5"
                $errorBox               = [System.Windows.Forms.TextBox]::New()
                $errorBox.Multiline     = $true
                $errorBox.ScrollBars    = [System.Windows.Forms.ScrollBars]::Vertical
                $errorBox.Height        = 280
                $errorBox.Width         = 250
                $errorBox.Location      = [System.Drawing.Point]::New(25, 10)
                $errorBox.WordWrap      = $true
                $errorBox.ReadOnly      = $true
                $errorBox.Text          = $value

                $popUpForm.Controls.Add($errorBox)
                $popUpForm.ShowDialog()
            })
        $this.VmInfoGridView.Add_CellContentClick(
            {
                $value = $this.Rows[$_.RowIndex].Cells[$_.ColumnIndex].ToolTipText

                if (-not $value.ToLower().StartsWith([ConstantStrings]::portalLinkPrefix))
                {
                    return
                }
                else
                {
                    [System.Diagnostics.Process]::Start($value)
                }
            })
        #EndRegion

        $this.PolicyForm.Controls.AddRange(
            @(
                #$MsLogo, # Commenting this for now.
                $SubscriptionIdLabel,
                $SubscriptionIdValueLabel,
                $GithubIssueLinkLabel,
                $ResourceGroupNameLabel,
                $ResourceGroupNameValueLabel,
                $PolicyAssignmentLabel,
                $PolicyAssignmentLinkLabel,
                $NonCompliantResourcesLabel,
                $NonCompliantResourcesValueLabel,
                $PolicyRemediationLabel,
                $PolicyRemediationLinkLabel
            )
        )
    }

    ### <summary>
    ### Launches the user interface.
    ### </summary>
    [void] Launch()
    {
        $this.PolicyForm.Controls.Add($this.VmInfoGridView)
        $this.PolicyForm.ShowDialog()
    }

    ### <summary>
    ### Adds VM information to the grid.
    ### </summary>
    ### <param name="vmInfo">Virtual machine information.</param>
    [void] AddVmInfoRow([VirtualMachine] $vmInfo)
    {
        if ($null -eq $vmInfo)
        {
            return
        }

        $vmInfo = $vmInfo | Sort-Object { $_.name }

        $suppress_output = $this.VmInfoGridView.Rows.Add(
            @(
                $vmInfo.Id,
                $(
                    if ([string]::IsNullOrEmpty($vmInfo.protectionState)) { "N/A" }
                    else { $vmInfo.protectionState }
                ),
                $(
                    if ([string]::IsNullOrEmpty($vmInfo.replicationHealth)) { "N/A" }
                    else { $vmInfo.replicationHealth }
                ),
                $vmInfo.protectedItemId,
                $vmInfo.deploymentId,
                $vmInfo.deploymentProvisioningState,
                $vmInfo.errors.Count
            )
        )
        $index = $this.VmInfoGridView.Rows.Count - 1
        $this.VmInfoGridView[[GridViewColumnName]::Errors, $index].ToolTipText =
            $(Out-String -InputObject $vmInfo.errors)

        $vmLinkCell = [System.Windows.Forms.DataGridViewLinkCell]::New()
        $vmLinkCell.Value = $vmInfo.name
        $vmLinkCell.LinkBehavior =
            [System.Windows.Forms.LinkBehavior]::AlwaysUnderline
        $vmLinkCell.ToolTipText = $vmInfo.portalUrl
        $vmLinkCell.LinkColor = [System.Drawing.Color]::DarkBlue
        $vmLinkCell.LinkVisited = $false;
        $vmLinkCell.TrackVisitedState = $false;
        $this.VmInfoGridView[[GridViewColumnName]::VirtualMachine, $index] = $vmLinkCell

        if ($vmInfo.IsProtected())
        {
            $protectedItemLinkCell = [System.Windows.Forms.DataGridViewLinkCell]::New()
            $protectedItemLinkCell.Value =
                $(Extract-ResourceNameFromId -ArmId $vmInfo.protectedItemId)
            $protectedItemLinkCell.LinkBehavior =
                [System.Windows.Forms.LinkBehavior]::AlwaysUnderline
            $protectedItemLinkCell.ToolTipText = $vmInfo.protectedItemPortalUrl
            $protectedItemLinkCell.LinkColor = [System.Drawing.Color]::DarkBlue
            $protectedItemLinkCell.LinkVisited = $false;
            $protectedItemLinkCell.TrackVisitedState = $false;
            $this.VmInfoGridView[[GridViewColumnName]::ReplicationProtectedItem, $index] =
                $protectedItemLinkCell
        }

        if (-not [string]::IsNullOrEmpty($vmInfo.deploymentId))
        {
            $deploymentLinkCell = [System.Windows.Forms.DataGridViewLinkCell]::New()
            $deploymentLinkCell.Value = $vmInfo.deploymentName
            $deploymentLinkCell.LinkBehavior =
                [System.Windows.Forms.LinkBehavior]::AlwaysUnderline
            $deploymentLinkCell.ToolTipText = $vmInfo.deploymentPortalUrl
            $deploymentLinkCell.LinkColor = [System.Drawing.Color]::DarkBlue
            $deploymentLinkCell.LinkVisited = $false;
            $deploymentLinkCell.TrackVisitedState = $false;
            $this.VmInfoGridView[[GridViewColumnName]::AsrDeployment, $index] = $deploymentLinkCell
        }

        $this.VmInfoGridView.Rows[$index].ReadOnly = $true
    }


    ### <summary>
    ### Adds information of multiple to the grid.
    ### </summary>
    ### <param name="vmInfoList">Virtual machine information list.</param>
    [void] AddVmInfoRows($vmInfoList)
    {
        foreach ($vmInfo in $vmInfoList) {
            $this.AddVmInfoRow($vmInfo)
        }
    }
}
#EndRegion

#Region Logger

### <summary>
###  Types of logs available.
### </summary>
Enum LogType
{
    ### <summary>
    ###  Log type is error.
    ### </summary>
    ERROR = 1

    ### <summary>
    ###  Log type is warning.
    ### </summary>
    WARNING = 2

    ### <summary>
    ###  Log type is debug.
    ### </summary>
    DEBUG = 3

    ### <summary>
    ###  Log type is information.
    ### </summary>
    INFO = 4

    ### <summary>
    ###  Log type is output.
    ### </summary>
    OUTPUT = 5
}

### <summary>
###  Class to log results.
### </summary>
class Logger
{
    ### <summary>
    ###  Gets the output file name.
    ### </summary>
    [string]$fileName

    ### <summary>
    ###  Gets the output file location.
    ### </summary>
    [string]$filePath

    ### <summary>
    ###  Gets the output line width.
    ### </summary>
    [int]$lineWidth

    ### <summary>
    ###  Indicates whether logs are disabled.
    ### </summary>
    [bool]$isDisabled

    ### <summary>
    ###  Gets the debug segment status.
    ### </summary>
    [bool]$isDebugSegmentOpen

    ### <summary>
    ###  Gets the debug output.
    ### </summary>
    [System.Object[]]$debugOutput

    ### <summary>
    ###  Initializes an instance of class OutLogger.
    ### </summary>
    ### <param name="name">Name of the file.</param>
    ### <param name="path">Local or absolute path to the file.</param>
    Logger(
        [String]$name,
        [string]$path,
        [bool]$isDisabled)
    {
        $this.fileName = $name
        $this.filePath = $path
        $this.isDisabled = $isDisabled
        $this.isDebugSegmentOpen = $false
        $this.lineWidth = 80
    }

    ### <summary>
    ###  Gets the full file path.
    ### </summary>
    [String] GetFullPath()
    {
        $path = $this.fileName + '.log'

        if($this.filePath)
        {
            if (-not (Test-Path $this.filePath))
            {
                Write-Warning "Invalid file path: $($this.filePath)"
                return $path
            }

            if ($this.filePath[-1] -ne "\")
            {
                $this.filePath = $this.filePath + "\"
            }

            $path = $this.filePath + $path
        }

        return $path
    }


    ### <summary>
    ###  Gets the full file path.
    ### </summary>
    ### <param name="invocationInfo">Gets the invocation information.</param>
    ### <param name="message">Gets the message to be logged.</param>
    ### <param name="type">Gets the type of log.</param>
    ### <return>String containing the formatted message -
    ### Type: DateTime ScriptName Line [Method]: Message.</return>
    [String] GetFormattedMessage(
        [System.Management.Automation.InvocationInfo] $invocationInfo,
        [string]$message,
        [LogType] $type)
    {
        $dateTime = Get-Date -uFormat "%d/%m/%Y %r"
        $line = $type.ToString() + "`t`t: $dateTime "
        $line +=
            "$($invocationInfo.scriptName.split('\')[-1]):$($invocationInfo.scriptLineNumber) " + `
            "[$($invocationInfo.invocationName)]: "
        $line += $message

        return $line
    }

    ### <summary>
    ###  Starts the debug segment.
    ### </summary>
    [Void] StartDebugLog()
    {
        $script:DebugPreference = "Continue"
        $this.isDebugSegmentOpen = $true
    }

    ### <summary>
    ###  Stops the debug segment.
    ### </summary>
    [Void] StopDebugLog()
    {
        $script:DebugPreference = "SilentlyContinue"
        $this.isDebugSegmentOpen = $false
    }

    ### <summary>
    ###  Gets the debug output and stores it in $DebugOutput.
    ### </summary>
    ### <param name="command">Command whose debug output needs to be redirected.</param>
    ### <return>Command modified to get the debug output to the success stream to be stored in
    ### a variable.</return>
    [string] GetDebugOutput([string]$command)
    {
        if ($this.isDebugSegmentOpen)
        {
            return '$(' + $command + ') 5>&1'
        }

        return $command
    }

    ### <summary>
    ###  Redirects the debug output to the output file.
    ### </summary>
    ### <param name="invocationInfo">Gets the invocation information.</param>
    ### <param name="command">Gets the command whose debug output needs to be redirected.</param>
    ### <return>Command modified to redirect debug stream to the log file.</return>
    [string] RedirectDebugOutput(
        [System.Management.Automation.InvocationInfo] $invocationInfo,
        [string]$command)
    {
        if ($this.isDebugSegmentOpen)
        {
            $this.Log(
                $InvocationInfo,
                "Debug output for command: $command`n",
                [LogType]::DEBUG)
            return $command + " 5>> $($this.GetFullPath())"
        }

        return $command
    }

    ### <summary>
    ###  Appends a message to the output file.
    ### </summary>
    ### <param name="invocationInfo">Gets the invocation information.</param>
    ### <param name="message">Gets the message to be logged.</param>
    ### <param name="type">Gets the type of log.</param>
    [Void] Log(
        [System.Management.Automation.InvocationInfo] $invocationInfo,
        [string] $message,
        [LogType] $type)
    {
        if ($this.isDisabled)
        {
            return
        }

        Out-File -FilePath $($this.GetFullPath()) -InputObject $this.GetFormattedMessage(
            $invocationInfo,
            $message,
            $type) -Append -NoClobber -Width $this.lineWidth
    }

    ### <summary>
    ###  Appends an object to the output file.
    ### </summary>
    ### <param name="invocationInfo">Gets the invocation information.</param>
    ### <param name="object">Gets the object to be logged.</param>
    ### <param name="type">Gets the type of log.</param>
    [Void] LogObject(
        [System.Management.Automation.InvocationInfo] $invocationInfo,
        $object,
        [LogType] $type)
    {
        if ($this.isDisabled)
        {
            return
        }

        Out-File -FilePath $($this.GetFullPath()) -InputObject $this.GetFormattedMessage(
            $invocationInfo,
            "`n",
            $type) -Append -NoClobber -Width $this.lineWidth
        Out-File -FilePath $($this.GetFullPath()) -InputObject $object -Append -NoClobber
    }
}
#EndRegion

#Region Constants

class ConstantStrings
{
    static [int] $deploymentNameMaxLength = 64

    static [string] $a2aProvider = "A2A"
    static [string] $apiVersion = "api-version"
    static [string] $authHeader = "authorization"
    static [string] $contentTypeJson ="application/json"
    static [string] $deploymentFailedState = "Failed"
    static [string] $deployments = "deployments"
    static [string] $deploymentsApiVersion = "2019-10-01"
    static [string] $deploymentSucceededState = "Succeeded"
    static [string] $httpGet = "GET"
    static [string] $githubIssue = "https://github.com/AsrOneSdk/policy-based-replication/" +
        "issues/new"
    static [string] $managementAzureEndpoint = "https://management.azure.com"
    static [string] $microsoftLogoLink = "https://c.s-microsoft.com/en-us/CMSImages/" +
        "ImgOne.jpg?version=D418E733-821C-244F-37F9-DC865BDEFEC0"
    static [string] $policyAssignmentPrefix = "AzureSiteRecovery-Replication-Policy-Assignment-"
    static [string] $policyDefinitionName = "AzureSiteRecovery-Replication-Policy"
    static [string] $policyDeploymentPrefix = "ASR-"
    static [string] $policyScriptUrl = "https://raw.githubusercontent.com/AsrOneSdk/" + `
        "policy-based-replication/master/prerequisite-script/policy-based-replication.ps1"
    static [string] $portalDeploymentDetailsBladePrefix = "https://portal.azure.com/" + `
        "#blade/HubsExtension/DeploymentDetailsBlade/outputs/id/"
    static [string] $portalLinkPrefix = "https://portal.azure.com/"
    static [string] $portalPolicyCreateRemediationTaskBladePrefix = "https://portal.azure.com/" + `
        "#blade/Microsoft_Azure_Policy/CreateRemediationTaskBlade/assignmentId/"
    static [string] $portalPolicyDetailedComplianceBladePrefix = "https://portal.azure.com/" + `
        "#blade/Microsoft_Azure_Policy/PolicyComplianceDetailedBlade/id/"
    static [string] $portalReplicationProtectedItemBladePrefix = "https://portal.azure.com/" + `
        "#blade/Microsoft_Azure_RecoveryServices/ReplicationProtectedItemSettingsMenuBlade/" + `
        "overviewmenuitem/replicationProtectedItemId/"
    static [string] $portalResourceLinkPrefix = "https://portal.azure.com/" + `
        "#@microsoft.onmicrosoft.com/resource"
    static [string] $powershellClientId = "1950a258-227b-4e31-a9cf-717495945fc2"
    static [string] $powershellRedirectUri = "urn:ietf:wg:oauth:2.0:oob"
    static [string] $powershellAuthorityUriPrefix = "https://login.windows.net/"
    static [string] $providers = "providers"
    static [string] $replicationEligibilityResults = "replicationEligibilityResults"
    static [string] $replicationProtectedItemName = "replicationProtectedItemName"
    static [string] $replicationProtectedItems = "replicationProtectedItems"
    static [string] $replicationProviderName = "replicationProviderName"
    static [string] $resourceGroups = "resourceGroups"
    static [string] $resourceLinks = "links"
    static [string] $resourceLinksApiVersion = "2016-09-01"
    static [string] $resourcesProvider = "Microsoft.Resources"
    static [string] $scopes = "scopes"
    static [string] $subscriptions = "subscriptions"
}
#EndRegion

#Region Errors

### <summary>
### Class to maintain all the errors.
### </summary>
class ErrorStrings
{
    ### <summary>
    ### Policy definition missing.
    ### </summary>
    ### <param name="definitionName">Definition name.</param>
    ### <param name="subscriptionId">Subscription Id.</param>
    ### <return>Error string.</return>
    static [string] PolicyDefinitionMissing([string] $definitionName, [string] $subscriptionId)
    {
        return "Policy definition - '$definitionName', could not be found under " +
            "subscription -'$subscriptionId'. Run the script located at " +
            "'$([ConstantStrings]::policyScriptUrl)' to define and assign policy for replication."
    }

    ### <summary>
    ### Policy assignment missing.
    ### </summary>
    ### <param name="definitionName">Definition name.</param>
    ### <param name="subscriptionId">Subscription Id.</param>
    ### <param name="resourceGroupName">Resource group name.</param>
    ### <return>Error string.</return>
    static [string] PolicyAssignmentMissing(
        [string] $definitionName,
        [string] $subscriptionId,
        [string] $resourceGroupName)
    {
        return "No policy assignment corresponding to definition - '$definitionName', could " +
            "not be found under resource group - '$resourceGroupName', in subscription - " +
            "'$subscriptionId'. Run the script located at " +
            "'$([ConstantStrings]::policyScriptUrl)' to define and assign policy for " +
            "replication. In case you've just run the script, wait up to 30 mins for the policy " +
            "to start."
    }

    ### <summary>
    ### No virtual machines found.
    ### </summary>
    ### <param name="resourceGroupName">Resource group name.</param>
    ### <param name="location">Location.</param>
    ### <return>Error string.</return>
    static [string] NoVirtualMachinesFound(
        [string] $resourceGroupName,
        [string] $location)
    {
        return "No virtual machines belonging to region - '$location', were found under " +
            "resource group - '$resourceGroupName'. Stopping script."
    }

    ### <summary>
    ### Inconsistent protected item information.
    ### </summary>
    ### <param name="vmId">Virtual machine id.</param>
    ### <param name="linkBasedId">Id as per the resource link.</param>
    ### <param name="objectBasedId">Id as per the protected item object.</param>
    ### <return>Error string.</return>
    static [string] InconsistentProtectedItemInformation(
        [string] $vmId,
        [string] $linkBasedId,
        [string] $objectBasedId)
    {
        return "The replication protected item information found for VM - '$vmId', seems " +
            "inconsistent. The protected item as per the resource link is '$linkBasedId' " +
            "while that according to the object found is '$objectBasedId'. An unexpected " +
            "code path has been hit."
    }

    ### <summary>
    ### ARM call failed.
    ### </summary>
    ### <param name="exceptionStr">Exception as string.</param>
    ### <param name="requestStr">Request as string.</param>
    ### <return>Error string.</return>
    static [string] ArmCallFailed(
        [string] $exceptionStr,
        [string] $requestStr)
    {
        return "ARM call failed with the following error:`n$exceptionStr" +
            "`nThe request information:`n$requestStr"
    }

    ### <summary>
    ### Api version missing.
    ### </summary>
    ### <return>Error string.</return>
    static [string] ApiVersionMissing()
    {
        return "API version related information is missing."
    }

    ### <summary>
    ### URL tokens missing.
    ### </summary>
    ### <return>Error string.</return>
    static [string] UrlTokensMissing()
    {
        return "Tokens for URL construction are missing."
    }

    ### <summary>
    ### Invalid ARM id input.
    ### </summary>
    ### <return>Error string.</return>
    static [string] InvalidArmIdInput()
    {
        return "The resource ARM id input is invalid."
    }

    ### <summary>
    ### Invalid label token input.
    ### </summary>
    ### <param name="armId">Resource ARM id.</param>
    ### <param name="tokenCount">Count of tokens.</param>
    ### <return>Error string.</return>
    static [string] InvalidLabelTokenInput(
        [string] $armId,
        [int] $tokenCount)
    {
        return "Labelled tokens cannot be created for ARM id - '$armId', as the token count " +
            "($tokenCount) is odd."
    }

    ### <summary>
    ### ASR deployment failure action.
    ### </summary>
    ### <return>Action string.</return>
    static [string] AsrDeploymentFailureAction()
    {
        return "View the deployment for more information. Fix the mentioned issue and " +
            "retry the operation."
    }
}
#EndRegion

#Region Models

### <summary>
###  Types of errors.
### </summary>
Enum ErrorType
{
    ### <summary>
    ###  Error type is EnableProtectionError.
    ### </summary>
    EnableProtectionError = 1

    ### <summary>
    ###  Error type is ASRValidationFailure.
    ### </summary>
    ASRValidationFailure = 2

    ### <summary>
    ###  Error type is ReplicationHealthError.
    ### </summary>
    ReplicationHealthError = 3
}

### <summary>
###  Class to maintain error information.
### </summary>
class Error
{
    ### <summary>
    ###  Gets the type.
    ### </summary>
    [ErrorType]$type

    ### <summary>
    ###  Gets the code.
    ### </summary>
    [string]$code

    ### <summary>
    ###  Gets the request or correlation id.
    ### </summary>
    [string]$requestId

    ### <summary>
    ###  Gets the message.
    ### </summary>
    [string]$message

    ### <summary>
    ###  Gets the user action to be performed.
    ### </summary>
    [string]$action

    ### <summary>
    ###  Initializes an instance of class Error.
    ### </summary>
    ### <param name="type">Error type.</param>
    ### <param name="requestId">Request id.</param>
    ### <param name="code">Error code.</param>
    ### <param name="message">Error message.</param>
    ### <param name="action">Error action.</param>
    Error(
        [ErrorType] $type,
        [string] $requestId,
        [string] $code,
        [string] $message,
        [string] $action)
    {
        $this.type = $type
        $this.requestId = $requestId.Trim('"')
        $this.code = $code
        $this.message = $message
        $this.action = $action
    }
}

### <summary>
###  Class to maintain ASR deployment information.
### </summary>
class ASRDeployment
{
    ### <summary>
    ###  Gets the name.
    ### </summary>
    [string] $name

    ### <summary>
    ###  Gets the resource group name.
    ### </summary>
    [string] $resourceGroupName

    ### <summary>
    ###  Gets the subscription id.
    ### </summary>
    [string] $subscriptionId

    ### <summary>
    ###  Gets the provisioning state.
    ### </summary>
    [string] $provisioningState

    ### <summary>
    ###  Gets the error.
    ### </summary>
    [Error[]] $errors

    ### <summary>
    ###  Constructs and gets the deployment ARM id.
    ### </summary>
    ### <returns>Deployment ARM Id</returns>
    [string] GetArmId()
    {
        return "/$([ConstantStrings]::subscriptions)/$($this.subscriptionId)" +
            "/$([ConstantStrings]::resourceGroups)/$($this.resourceGroupName)" +
            "/providers/Microsoft.Resources/deployments/$($this.name)"
    }
}

### <summary>
###  Class to maintain virtual machine information.
### </summary>
class VirtualMachine
{
    ### <summary>
    ###  Gets the name.
    ### </summary>
    [string] $name

    ### <summary>
    ###  Gets the ARM id.
    ### </summary>
    [string] $id

    ### <summary>
    ###  Gets the VM's portal url.
    ### </summary>
    [string] $portalUrl

    ### <summary>
    ###  Gets the location.
    ### </summary>
    [string] $location

    ### <summary>
    ###  Gets the resource group name.
    ### </summary>
    [string] $resourceGroupName

    ### <summary>
    ###  Gets the id of the corresponding protected item.
    ### </summary>
    [string] $protectedItemId

    ### <summary>
    ###  Gets the protected item portal link.
    ### </summary>
    [string] $protectedItemPortalUrl

    ### <summary>
    ###  Gets the protection state.
    ### </summary>
    [string] $protectionState

    ### <summary>
    ###  Gets the replication health.
    ### </summary>
    [string] $replicationHealth

    ### <summary>
    ###  Gets the deployment name.
    ### </summary>
    [string] $deploymentName

    ### <summary>
    ###  Gets the deployment ARM id.
    ### </summary>
    [string] $deploymentId

    ### <summary>
    ###  Gets the deployment resource group name.
    ### </summary>
    [string] $deploymentResourceGroupName

    ### <summary>
    ###  Gets the deployment provisioning state.
    ### </summary>
    [string] $deploymentProvisioningState

    ### <summary>
    ###  Gets the deployment portal link.
    ### </summary>
    [string] $deploymentPortalUrl

    ### <summary>
    ###  Gets the errors.
    ### </summary>
    [System.Collections.ArrayList] $errors

    ### <summary>
    ###  Initializes an instance of class VirtualMachine.
    ### </summary>
    ### <param name="virtualMachine">Virtual machine.</param>
    VirtualMachine($virtualMachine)
    {
        $this.name = $virtualMachine.Name
        $this.id = $virtualMachine.Id
        $this.location = $virtualMachine.Location
        $this.resourceGroupName = $virtualMachine.ResourceGroupName
        $this.errors = [System.Collections.ArrayList]::New()
    }

    ### <summary>
    ###  Gets a value indicating whether the VM is protected using ASR or not.
    ### </summary>
    [bool] IsProtected()
    {
        return -not [string]::IsNullOrEmpty($this.protectedItemId)
    }

    ### <summary>
    ### Populate the portal url properties.
    ### </summary>
    [void] PopulatePortalUrls()
    {
        $this.portalUrl = [ConstantStrings]::portalResourceLinkPrefix + "/" + $this.id.Trim('/')

        if (-not [string]::IsNullOrEmpty($this.protectedItemId))
        {
            $this.protectedItemPortalUrl =
                [ConstantStrings]::portalReplicationProtectedItemBladePrefix + `
                [uri]::EscapeDataString('/' + $this.protectedItemId.Trim('/')) + "/" + `
                [ConstantStrings]::replicationProtectedItemName + "/" + $this.name + "/" + `
                [ConstantStrings]::replicationProviderName + "/" + [ConstantStrings]::a2aProvider
        }

        if (-not [string]::IsNullOrEmpty($this.deploymentId))
        {
            $this.deploymentPortalUrl =
                [ConstantStrings]::portalDeploymentDetailsBladePrefix + `
                [uri]::EscapeDataString('/' + $this.deploymentId.Trim('/'))
        }
    }

    ### <summary>
    ### Adds a health error to the error list.
    ### </summary>
    [void] AddReplicationHealthError($healthError)
    {
        if ($null -eq $healthError)
        {
            return
        }

        $this.errors.Add(
            [Error]::New(
                [ErrorType]::ReplicationHealthError,
                $null,
                $healthError.ErrorCode,
                $healthError.ErrorMessage + "`n" + $healthError.PossibleCauses,
                $healthError.RecommendedAction
            ))
    }

    ### <summary>
    ### Adds health errors to the error list.
    ### </summary>
    [void] AddReplicationHealthErrors($healthErrors)
    {
        if ($null -eq $healthErrors)
        {
            return
        }

        $healthErrors | % { $this.AddReplicationHealthError($_) }
    }
}
#EndRegion

#Region Utilities

### <summary>
### Extracts the labelled tokens from the ARM id.
### </summary>
### <param name="armId">Resource ARM id.</param>
### <returns>Labelled tokens in lowercase.</returns>
function Extract-LabelledTokensFromId([string] $armId)
{
    if ([string]::IsNullOrEmpty($armId))
    {
        throw [ErrorStrings]::InvalidArmIdInput()
    }

    $tokens = $armId.ToLower().Trim('/').Split('/')

    if (($tokens.Count % 2) -ne 0)
    {
        throw [ErrorStrings]::InvalidLabelTokenInput($armId.ToLower().Trim('/'), $tokens.Count)
    }

    $labelledTokens = [System.Collections.Hashtable]::New()

    for ($index=0; $index -lt $tokens.Count; $index += 2)
    {
        $labelledTokens.Add($tokens[$index], $tokens[$index + 1])
    }

    return $labelledTokens
}

### <summary>
### Extracts the resource group from ARM id.
### </summary>
### <param name="armId">Resource ARM id.</param>
### <returns>Resource group name.</returns>
function Extract-ResourceGroupFromId([string] $armId)
{
    $tokens = Extract-LabelledTokensFromId -ArmId $armId

    return $tokens[[ConstantStrings]::resourceGroups.ToLower()]
}

### <summary>
### Extracts the resource name from ARM id.
### </summary>
### <param name="armId">Resource ARM id.</param>
### <returns>Resource name.</returns>
function Extract-ResourceNameFromId([string] $armId)
{
    if ([string]::IsNullOrEmpty($armId))
    {
        throw [ErrorStrings]::InvalidArmIdInput()
    }

    $tokens = $armId.Trim('/').Split('/')

    return $tokens[-1]
}

### <summary>
### Extracts the resource type from ARM id.
### </summary>
### <param name="armId">Resource ARM id.</param>
### <returns>Resource name.</returns>
function Extract-ResourceTypeFromId([string] $armId)
{
    if ([string]::IsNullOrEmpty($armId))
    {
        throw [ErrorStrings]::InvalidArmIdInput()
    }

    $tokens = $armId.Trim('/').Split('/')

    return $tokens[-2]
}

### <summary>
### Forms the url string from the tokens passed.
### </summary>
### <param name="apiVersion">Api version.</param>
### <param name="tokens">Url string tokens.</param>
### <returns>Url string.</returns>
function Get-UrlString([string] $apiVersion, [string[]]$tokens)
{
    if ([string]::IsNullOrEmpty($apiVersion))
    {
        throw [ErrorStrings]::ApiVersionMissing()
    }

    if ($null -eq $tokens)
    {
        throw [ErrorStrings]::UrlTokensMissing()
    }

    $url = [ConstantStrings]::managementAzureEndpoint + '/'
    $url += $tokens.Trim('/') -Join '/'
    $url = $url.Trim('/')
    $url += '?' + [ConstantStrings]::apiVersion + '=' + $apiVersion

    return $url
}
#EndRegion

#Region REST

### <summary>
### Invokes ARM call in a uniform manner.
### </summary>
### <param name="parameters">REST call parameters.</param>
### <returns>Response.</returns>
function Invoke-ArmCall($parameters)
{
    try
    {
        $response = Invoke-RestMethod @parameters
    }
    catch
    {
        throw [ErrorStrings]::ArmCallFailed(
            $(Out-String -InputObject $PSItem),
            $(Out-String -InputObject $parameters))
    }
    finally
    {
        Write-Verbose "`nRequest: `n$(Out-String -InputObject $Params)"
        Write-Verbose "`nResonse: `n$(Out-String -InputObject $Response)"
    }

    return $response
}

### <summary>
### Gets the authentication result to management.azure.com endpoint.
### </summary>
### <param name="tenantId">The tenant id.</param>
function Get-Authentication([string] $tenantId)
{
    Write-Verbose "`nFetching auth token."

    $AuthorityUri = [ConstantStrings]::powershellAuthorityUriPrefix + $tenantId
    $AuthContext =
        [Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationContext]::New($AuthorityUri)
    $PlatformParameters =
        [Microsoft.IdentityModel.Clients.ActiveDirectory.PlatformParameters]::New("Auto", $null)
    $AuthResult =
        $AuthContext.AcquireTokenAsync(
            [ConstantStrings]::managementAzureEndpoint,
            [ConstantStrings]::powershellClientId,
            [ConstantStrings]::powershellRedirectUri,
            $PlatformParameters)

    return $AuthResult.Result
}

### <summary>
### Gets the resource links at resource group scope.
### </summary>
### <param name="resourceGroupName">Resource group name.</param>
### <returns>List of resource link source id to target id mappings.</returns>
function Get-ResourceLinks([string] $resourceGroupName)
{
    Write-Host -ForegroundColor Green "Fetching resource links under '$resourceGroupName'" `
        "resource group..."

    $context = Get-AzContext
    $token = Get-Authentication -TenantId $context.Tenant.Id
    $url = Get-UrlString -ApiVersion $([ConstantStrings]::resourceLinksApiVersion) -Tokens `
        @(
            [ConstantStrings]::subscriptions,
            $context.Subscription.Id,
            [ConstantStrings]::resourceGroups,
            $resourceGroupName,
            [ConstantStrings]::providers,
            [ConstantStrings]::resourcesProvider,
            [ConstantStrings]::resourceLinks
        )

    $params = @{
        ContentType = [ConstantStrings]::contentTypeJson
        Headers     = @{
            [ConstantStrings]::authHeader = "Bearer $($token.AccessToken)"}
        Method      = [ConstantStrings]::httpGet
        URI         = $url
    }

    $response = Invoke-ArmCall -Parameters $params
    $properties = $response.value.properties | `
        Where-Object {
            $(Extract-ResourceTypeFromId -ArmId $_.TargetId) -like `
            [ConstantStrings]::replicationProtectedItems
        }

    return $properties
}
#EndRegion

#Region Log

### <summary>
### Logging the parameters passed during this script run.
### </summary>
function Log-ScriptParameters()
{
    try
    {
        $commandName = $PSCmdlet.MyInvocation.InvocationName;
        $parameterList = (Get-Command -Name $CommandName).Parameters;

        foreach ($parameter in $parameterList) {
            $parameters = Get-Variable -Name $Parameter.Values.Name -ErrorAction SilentlyContinue
        }

        $OutputLogger.LogObject(
            $MyInvocation,
            $parameters,
            [LogType]::INFO)
    }
    catch
    {
        Write-Warning "Unable to log script parameters."
    }
}

### <summary>
### Logging general policy information.
### </summary>
### <param name="policyAssignment">Policy assignment.</param>
function Log-PolicyInformation($policyAssignment)
{
    $policyParams = $policyAssignment.Properties.Parameters
    $policyAssignmentSummary = Get-PolicyAssignmentSummary -PolicyAssignment $policyAssignment

    Write-Host -ForegroundColor Green "Policy assignment found:"
    Write-Host -ForegroundColor Green "`nPolicy Assignment - $($policyAssignment.Name)"
    Write-Host -ForegroundColor Green "Resource group - $($policyAssignment.ResourceGroupName)"
    Write-Host -ForegroundColor Green "Vault Id - $($policyParams.VaultId.Value)"
    Write-Host -ForegroundColor Green "Source region - $($policyParams.SourceRegion.Value)"
    Write-Host -ForegroundColor Green "Target region - $($policyParams.TargetRegion.Value)"

    $OutputLogger.Log(
        $MyInvocation,
        "`nParameters for policy assignment -'$($policyAssignment.ResourceId)':`n",
        [LogType]::OUTPUT)

    $OutputLogger.LogObject(
        $MyInvocation,
        $policyParams,
        [LogType]::OUTPUT)

    if ($null -eq $policyAssignmentSummary)
    {
        $message = "`nCouldn't locate the summary for policy assignment - " +
            "$($policyAssignment.Name)"

        Write-Host -ForegroundColor Yellow $message
        $OutputLogger.Log(
            $MyInvocation,
            $message,
            [LogType]::WARNING)
    }
    else
    {
        Write-Host -ForegroundColor Green "Non-compliant resources -" `
            "$($policyAssignmentSummary.Results.NonCompliantResources)"
        $OutputLogger.LogObject(
            $MyInvocation,
            $policyAssignmentSummary,
            [LogType]::OUTPUT)
    }

    Write-Host "`n"
}

### <summary>
### Logging helpful policy urls.
### </summary>
### <param name="policyAssignment">Policy assignment.</param>
function Log-PolicyUrls($policyAssignment)
{
    $complianceDetailedBladeScope = '["/' + [ConstantStrings]::subscriptions + '/' + `
        $(Get-AzContext).Subscription.Id + '"]'
    $assignmentCompliancePage = [ConstantStrings]::portalPolicyDetailedComplianceBladePrefix + `
        [uri]::EscapeDataString($policyAssignment.ResourceId) + "/" + [ConstantStrings]::scopes + `
        "/" + [uri]::EscapeDataString($complianceDetailedBladeScope)
    $newRemediationTaskPage = [ConstantStrings]::portalPolicyCreateRemediationTaskBladePrefix + `
        [uri]::EscapeDataString($policyAssignment.ResourceId) + "/" + [ConstantStrings]::scopes + `
        "/" + [uri]::EscapeDataString($complianceDetailedBladeScope)

    $OutputLogger.Log(
        $MyInvocation,
        "Helpful Policy URLs -`n",
        [LogType]::OUTPUT)
    $OutputLogger.Log(
        $MyInvocation,
        "Detailed Policy Assignment Compliance Page:`n" + $assignmentCompliancePage + "`n",
        [LogType]::OUTPUT)
    $OutputLogger.Log(
        $MyInvocation,
        "Create New Remediation Task:`n" + $newRemediationTaskPage + "`n",
        [LogType]::OUTPUT)
}

### <summary>
### Logging virtual machine information.
### </summary>
### <param name="vmInfoList">VM info list.</param>
function Log-VirtualMachineInformation($vmInfoList)
{
    foreach ($vm in $vmInfoList){
        $output = "`n"
        $output += $(Out-String -InputObject $vm).Trim("`n")
        $output += "ErrorDetails:" + $(Out-String -InputObject $vm.errors).Trim("`n")

        $OutputLogger.Log(
            $MyInvocation,
            $output,
            [LogType]::OUTPUT)

        if ($OutputLogger.IsDisabled -and (-not $enableGUI))
        {
            Write-Host -ForegroundColor Green $output
        }
    }


    if (-not $OutputLogger.IsDisabled)
    {
        Write-Host -ForegroundColor Green "`nVirtual machine information logged in file -" `
            "'$($OutputLogger.GetFullPath())'"
    }
}
#EndRegion

#Region Policy

### <summary>
### Gets the policy assignment summary.
### </summary>
### <param name="policyAssignment">Policy assignment.</param>
### <returns>Policy assignment summary.</returns>
function Get-PolicyAssignmentSummary($policyAssignment)
{
    $policySummary = Get-AzPolicyStateSummary -ErrorAction Ignore -PolicyDefinitionName `
        $(Extract-ResourceNameFromId -ArmId $policyAssignment.Properties.policyDefinitionId)

    $policyAssignmentSummary = $null

    if ($null -ne $policySummary)
    {
        $policyAssignmentSummary = $policySummary.PolicyAssignments | `
            Where-Object {
                $_.PolicyAssignmentId.Trim('/') -like $policyAssignment.ResourceId.Trim('/')
            }
    }

    return $policyAssignmentSummary
}

### <summary>
### Gets the policy assignment based on scope.
### </summary>
### <param name="subscriptionId">Subscription Id.</param>
### <param name="sourceResourceGroupName">Source resource group name.</param>
### <returns>Policy assignment.</returns>
function Get-PolicyAssignment([string] $subscriptionId, [string] $sourceResourceGroupName)
{
    $context = Get-AzContext
    $sourceResourceGroup = Get-AzResourceGroup -Name $sourceResourceGroupName
    $policyDefinition = Get-AzPolicyDefinition -Name $([ConstantStrings]::policyDefinitionName)

    if ($null -eq $policyDefinition)
    {
        throw [ErrorStrings]::PolicyDefinitionMissing(
            [ConstantStrings]::policyDefinitionName,
            $context.Subscription.Id)
    }

    $policyScope = "/$([ConstantStrings]::subscriptions)/$subscriptionId/" + `
        "$([ConstantStrings]::resourceGroups)/$sourceResourceGroupName"
    $policyAssignment = Get-AzPolicyAssignment -Scope $policyScope -PolicyDefinitionId `
        $policyDefinition.ResourceId

    if ($null -eq $policyAssignment)
    {
        throw [ErrorStrings]::PolicyAssignmentMissing(
            [ConstantStrings]::policyDefinitionName,
            $context.Subscription.Id,
            $sourceResourceGroupName)
    }

    if ($null -ne $policyAssignment.Count)
    {
        $policyAssignment = $policyAssignment[0]
    }

    Log-PolicyInformation -PolicyAssignment $policyAssignment

    return $policyAssignment
}
#EndRegion

#Region Prereq

### <summary>
### Sets Azure context.
### </summary>
function Set-Context()
{
    $context = Get-AzContext

    if ($null -eq $context)
    {
        $suppressOutput = Login-AzAccount
    }

    $context = Get-AzContext
    $OutputLogger.Log(
        $MyInvocation,
        "User context set - $($context.Account.Id)($($context.Account.Type)).",
        [LogType]::INFO)

    $suppressOutput = Select-AzSubscription -SubscriptionId $subscriptionId
}
#EndRegion

#Region Deployment

### <summary>
### Gets the latest deployment operation.
### </summary>
### <param name="deployment">Deployment.</param>
### <returns>Latest operation.</returns>
function Get-LatestDeploymentOperation($deployment)
{
    $ops = Get-AzResourceGroupDeploymentOperation -ResourceGroupName `
        $deployment.ResourceGroupName -DeploymentName $deployment.DeploymentName | `
        Where-Object { $null -ne $_.properties.statusMessage.Error }

    return ($ops | Sort-Object -Descending {[datetime] $_.Properties.Timestamp})[0]
}

### <summary>
### Generate the ASR deployment.
### </summary>
### <param name="deployment">Deployment.</param>
### <returns>ASR deployment.</returns>
function Get-AsrDeployment($deployment)
{
    $asrDeployment = [ASRDeployment]::New()
    $asrDeployment.Name = $deployment.DeploymentName
    $asrDeployment.ResourceGroupName = $deployment.ResourceGroupName
    $asrDeployment.SubscriptionId = $(Get-AzContext).Subscription.Id
    $asrDeployment.ProvisioningState = $deployment.ProvisioningState

    if ($deployment.ProvisioningState -like [ConstantStrings]::deploymentFailedState)
    {
        $operation = Get-LatestDeploymentOperation -Deployment $deployment

        $deploymentError =
            [Error]::New(
                [ErrorType]::EnableProtectionError,
                $deployment.CorrelationId,
                $operation.Properties.StatusMessage.Error.Code,
                $operation.Properties.StatusMessage.Error.Message,
                [ErrorStrings]::AsrDeploymentFailureAction())

        $asrDeployment.Errors = @($deploymentError)
    }
    elseif ($deployment.ProvisioningState -like [ConstantStrings]::deploymentSucceededState)
    {
        $validationOutput = $deployment.Outputs[[ConstantStrings]::replicationEligibilityResults]

        if ($null -ne $validationOutput.Value.errors)
        {
            $clientRequestId = [Newtonsoft.Json.JsonConvert]::SerializeObject(
                $validationOutput.Value.clientRequestId)
            $serializedErrors = [Newtonsoft.Json.JsonConvert]::SerializeObject(
                $validationOutput.Value.errors)
            $asrErrors =
                [Newtonsoft.Json.JsonConvert]::DeserializeObject(
                    $serializedErrors,
                    [Microsoft.Azure.Commands.RecoveryServices.SiteRecovery.Error[]])

            $asrDeploymentErrors = [System.Collections.ArrayList]::New()

            foreach ($asrError in $asrErrors)
            {
                $deploymentError =
                    [Error]::New(
                        [ErrorType]::ASRValidationFailure,
                        $clientRequestId,
                        $asrError.Code,
                        $asrError.Message + "`n" + $asrErrors.PossibleCauses,
                        $asrError.RecommendedAction)

                $suppressIndex = $asrDeploymentErrors.Add($deploymentError)
            }

            $asrDeployment.Errors = $asrDeploymentErrors.ToArray()
        }
    }

    return $asrDeployment
}
#EndRegion

#Region ASR

### <summary>
### Sets the ASR vault context.
### </summary>
### <param name="vaultId">The vault ARM id.</param>
function Set-RecoveryServicesVaultContext([string] $vaultId)
{
    $vaultName = Extract-ResourceNameFromId -ArmId $vaultId
    $vaultResourceGroupName = Extract-ResourceGroupFromId -ArmId $vaultId

    $vault = Get-AzRecoveryServicesVault -ResourceGroupName $vaultResourceGroupName -Name `
        $vaultName -ErrorAction Stop
    $vaultContext = Set-AzRecoveryServicesAsrVaultSettings -Vault $vault
}

### <summary>
### Gets the list of protected items.
### </summary>
### <param name="vaultId">The vault ARM id.</param>
function Get-ProtectedItems([string] $vaultId)
{
    Write-Host -ForegroundColor Green "Fetching protected items under vault" `
        "'$(Extract-ResourceNameFromId -ArmId $vaultId)'..."

    Set-RecoveryServicesVaultContext -VaultId $vaultId

    return Get-ASRFabric | Get-ASRProtectionContainer | Get-ASRReplicationProtectedItem
}
#EndRegion

#Region Azure

### <summary>
### Gets the virtual machine information.
### </summary>
### <param name="resourceGroupName">Resource group name.</param>
### <param name="vaultResourceGroupName">Vault resource group name.</param>
### <param name="location">Location.</param>
### <param name="protectedItems">List of protected items.</param>
### <returns>List of virtual machines.</returns>
function Get-VirtualMachineInformation(
    [string] $resourceGroupName,
    [string] $vaultResourceGroupName,
    [string] $location,
    $protectedItems)
{
    Write-Host -ForegroundColor Green "Gathering virtual machine information..."

    $vms = Get-AzVM -ResourceGroupName $resourceGroupName | `
        Where-Object { $_.Location -like $location }

    if ($null -eq $vms)
    {
        Write-Host -ForegroundColor Yellow $(
            [ErrorStrings]::NoVirtualMachinesFound($resourceGroupName, $location))
        exit
    }

    $deploymentPrefix = ([ConstantStrings]::policyDeploymentPrefix + $resourceGroupName).ToLower()
    $resourceLinks = Get-ResourceLinks -ResourceGroupName $resourceGroupName
    $deployments = Get-AzResourceGroupDeployment -ResourceGroupName $vaultResourceGroupName | `
        Where-Object { $_.DeploymentName.ToLower().StartsWith($deploymentPrefix) }

    Write-Host -ForegroundColor Green "Correlating VMs with resource links, protected items, and" `
        "deployments..."

    $vmInfoList = [System.Collections.ArrayList]::New()

    foreach ($vm in $vms)
    {
        $index = $vmInfoList.Add([VirtualMachine]::New($vm))

        $correspondingProtectedItem = $protectedItems | `
            Where-Object {
                $_.ProviderSpecificDetails.FabricObjectId.Trim('/') -like $vm.Id.Trim('/')
            }
        $correspondingLink = $resourceLinks |
            Where-Object {$_.SourceId.Trim('/') -like $vm.Id.Trim('/')}
        $correspondingDeployment = $deployments |`
            Where-Object {
                $expectedName = ($deploymentPrefix + "-" + $vm.Name).ToLower()

                if ($expectedName.Length -ge [ConstantStrings]::deploymentNameMaxLength)
                {
                    $expectedName =
                        $expectedName.Substring(0, [ConstantStrings]::deploymentNameMaxLength)
                }

                # CHANGE THIS TO -like after testing as the new policy doesnt add guid at the end.
                $_.DeploymentName.ToLower() -like $expectedName
            }

        if ($null -ne $correspondingLink)
        {
            $vmInfoList[$index].protectedItemId = $correspondingLink.TargetId

            if (($null -ne $correspondingProtectedItem) -and `
                ($correspondingProtectedItem.Id.Trim('/') -notlike `
                    $vmInfoList[$index].protectedItemId.Trim('/')))
            {
                # Unexpected code path.
                throw [ErrorStrings]::InconsistentProtectedItemInformation(
                    $vm.Id,
                    $vmInfoList[$index].protectedItemId,
                    $vmInfoList[$index].ReplicationProtectedItem.Id.Trim('/'))
            }
        }

        if ($null -ne $correspondingProtectedItem)
        {
            $vmInfoList[$index].protectionState = $correspondingProtectedItem.ProtectionState
            $vmInfoList[$index].ReplicationHealth = $correspondingProtectedItem.ReplicationHealth
            $vmInfoList[$index].AddReplicationHealthErrors(
                $correspondingProtectedItem.ReplicationHealthErrors)
        }

        if ($null -ne $correspondingDeployment)
        {
            $asrDeployment = Get-AsrDeployment -Deployment $correspondingDeployment

            $vmInfoList[$index].deploymentName = $asrDeployment.Name
            $vmInfoList[$index].deploymentId = $asrDeployment.GetArmId()
            $vmInfoList[$index].deploymentResourceGroupName = $asrDeployment.ResourceGroupName
            $vmInfoList[$index].deploymentProvisioningState = $asrDeployment.ProvisioningState

            if ($null -ne $asrDeployment.errors)
            {
                $vmInfoList[$index].errors.AddRange($asrDeployment.errors)
            }
        }

        $vmInfoList[$index].PopulatePortalUrls()
    }

    return $vmInfoList
}
#EndRegion

#Region Main

### <summary>
### Main function.
### </summary>
function Start-Main()
{
    Set-Context

    $policyAssignment = Get-PolicyAssignment -SubscriptionId $subscriptionId `
        -SourceResourceGroupName $sourceResourceGroupName
    $policyParameters = $policyAssignment.Properties.Parameters
    $vaultId = $policyParameters.VaultId.Value
    $protectedItems = Get-ProtectedItems -VaultId $vaultId

    $vmInfoList = Get-VirtualMachineInformation -ResourceGroupName $sourceResourceGroupName `
        -VaultResourceGroupName $(Extract-ResourceGroupFromId -ArmId $vaultId) `
        -ProtectedItems $protectedItems -Location $policyParameters.sourceRegion.value

    Log-PolicyUrls -PolicyAssignment $policyAssignment
    Log-VirtualMachineInformation -VmInfoList $vmInfoList

    if (-not $enableGUI)
    {
        return
    }

    $policyUI = [UserInterface]::New($subscriptionId, $sourceResourceGroupName, $policyAssignment)
    $policyUI.AddVmInfoRows($vmInfoList)
    $policyUI.Launch()
}
#EndRegion

#Region Script
$WarningPreference = "SilentlyContinue"
$ErrorActionPreference = "Stop"
$StartTime = Get-Date -Format 'dd-MM-yyyy-HH-mm-ss'
$OutputLogger = [Logger]::new(
    'PolicySurveillance-' + $StartTime,
    $logFileLocation,
    (-not $enableLog) -and [string]::IsNullOrEmpty($logFileLocation))
$OutputLogger.Log(
    $MyInvocation,
    "StartTime - $StartTime",
    [LogType]::INFO)

try
{
    Log-ScriptParameters
    Start-Main
}
catch
{
    Write-Host -ForegroundColor Red -BackgroundColor Black $(Out-String -InputObject $PSItem)

    $OutputLogger.LogObject(
        $MyInvocation,
        $PSItem,
        [LogType]::ERROR)
}
finally
{
    $EndTime = Get-Date -Format 'dd-MM-yyyy-HH-mm-ss'
    $OutputLogger.Log(
        $MyInvocation,
        "EndTime - $EndTime",
        [LogType]::INFO)
}
#EndRegion