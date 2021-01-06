clear-host
$script_path = $MyInvocation.MyCommand.Path
$script_dir = Split-Path -Parent $script_path
$ScriptName = ($MyInvocation.MyCommand.Name).Replace(".ps1", "")
$GUIFile = $script_dir + "\GUI\MainWindow.xaml"
Write-Host $GUIFile

$ConsoleLog = $env:windir + "\Logs\WPT_" + $ScriptName + ".log"
[int]$WaitToClose = 5  #defeines the sleep-timer in seconds to close the Progressbar 

Start-Transcript -path $ConsoleLog

Add-Type -AssemblyName presentationframework, presentationcore, System.Drawing, System.Windows.Forms, WindowsFormsIntegration
[reflection.assembly]::loadwithpartialname("System.Windows.Forms") | Out-Null
[reflection.assembly]::loadwithpartialname("System.Drawing") | Out-Null

# Mahapps Library required for SplashScreen
[System.Reflection.Assembly]::LoadFrom($script_dir + "\GUI\assembly\MahApps.Metro.dll") | out-null
[System.Reflection.Assembly]::LoadFrom($script_dir + "\GUI\assembly\System.Windows.Interactivity.dll") | out-null

#endregion



#load GUI from XAML File
$Global:wpf = @{ }
$inputXML = Get-Content -Path $GUIFile
$inputXMLClean = $inputXML -replace 'mc:Ignorable="d"', '' -replace "x:N", 'N' -replace 'x:Class=".*?"', '' -replace 'd:DesignHeight="\d*?"', '' -replace 'd:DesignWidth="\d*?"', ''
[xml]$xaml = $inputXMLClean
$reader = New-Object System.Xml.XmlNodeReader $xaml
$tempform = [Windows.Markup.XamlReader]::Load($reader)
$namedNodes = $xaml.SelectNodes("//*[@*[contains(translate(name(.),'n','N'),'Name')]]")
$namedNodes | ForEach-Object { $Global:wpf.Add($_.Name, $tempform.FindName($_.Name)) }

#region button Start Progress
$wpf.btnStart.add_Click( {
    Start-ProgressBar
    
    close-ProgressBar
})
#endregion

#region button LogFolder
$wpf.btnExit.add_Click( {
	Stop-Transcript
	$wpf.Main.Close() | out-null
})
#endregion

function close-ProgressBar (){
    $hash.window.Dispatcher.Invoke("Normal",[action]{ $hash.window.close() })
	$Pwshell.EndInvoke($handle) 
	#$runspace.Close() #| Out-Null

}

function Start-ProgressBar{
    $Pwshell.Runspace = $runspace
    $script:handle = $Pwshell.BeginInvoke()
}

$hash = [hashtable]::Synchronized(@{})
    $runspace = [runspacefactory]::CreateRunspace()
    $runspace.ApartmentState = "STA"
    $Runspace.ThreadOptions = "ReuseThread"
    $runspace.Open()
    $runspace.SessionStateProxy.SetVariable("hash",$hash)
    $runspace.SessionStateProxy.SetVariable("script_dir",$script_dir)
    $runspace.SessionStateProxy.SetVariable("WaitToClose",$WaitToClose)
    $Pwshell = [PowerShell]::Create()

    $Pwshell.AddScript({
    $xml = [xml]@"
     <Window
	xmlns:Controls="clr-namespace:MahApps.Metro.Controls;assembly=MahApps.Metro"
	xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
	xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
	x:Name="WindowSplash" Title="SplashScreen" WindowStyle="None" WindowStartupLocation="CenterScreen"
	Background="DarkGray" ShowInTaskbar ="false"
	Width="700" Height="200" ResizeMode = "NoResize" >

	<Grid>
		<Grid.RowDefinitions>
            <RowDefinition Height="70"/>
            <RowDefinition/>
        </Grid.RowDefinitions>

		<Grid Grid.Row="0" x:Name="Header" >
			<StackPanel Orientation="Horizontal" HorizontalAlignment="Center" VerticalAlignment="Stretch" Margin="20,10,0,0">
				<Image x:Name="Logo" RenderOptions.BitmapScalingMode="Fant" HorizontalAlignment="Left" Margin="0,0,0,0" Width="60" Height="60" VerticalAlignment="Top" />
			    <Label x:Name="Title" Margin="5,0,0,0" Foreground="White" Height="50"  FontSize="30"/>
			</StackPanel>
		</Grid>
        <Grid Grid.Row="1" >
		 	<StackPanel Orientation="Vertical" HorizontalAlignment="Center" VerticalAlignment="Center" Margin="5,5,5,5">
                <ProgressBar x:Name="wpfProgressbar" IsIndeterminate="False" Minimum="0" Maximum="100" Height="20" />
                <TextBlock Text="{Binding ElementName=wpfProgressbar, Path=Value, StringFormat={}{0:0}%}" HorizontalAlignment="Center" VerticalAlignment="Center" Foreground="White"/>
                <Label x:Name = "LoadingLabel" Foreground="White" HorizontalAlignment="Center" VerticalAlignment="Center" FontSize="24" Margin = "0,0,0,0"/>
				<Controls:MetroProgressBar IsIndeterminate="True" Foreground="White" HorizontalAlignment="Center" Width="350" Height="20"/>
			</StackPanel>
        </Grid>
	</Grid>

</Window>
"@




    $reader = New-Object System.Xml.XmlNodeReader $xml
    $hash.window = [Windows.Markup.XamlReader]::Load($reader)
    $hash.LoadingLabel = $hash.window.FindName("LoadingLabel")
    $hash.Logo = $hash.window.FindName("Logo")
    $hash.Title = $hash.window.FindName("Title")
    $hash.wpfProgressbar = $hash.window.FindName("wpfProgressbar")

    $hash.Logo.Source = "$script_dir\GUI\resources\logo.png"
	$hash.LoadingLabel.Content= "Loading - please wait"
    
    $TimerProgress = {
        $StartDate = get-date 
        $hash.Title.Content = "Waiting $WaitToClose seconds | $StartDate"
        $hash.wpfProgressbar.Value = ( 100 / $WaitToClose )
        $hash.Title.Content = "Waiting $WaitToClose seconds | $StartDate"
	}
	
	$timer= New-Object System.windows.Forms.Timer
	$timer.Enabled = $True
	$timer.Interval = 1
    $timer.Start() 
	$timer.Add_Tick($TimerProgress)
    
    $hash.window.ShowDialog()

}) | Out-Null


$wpf.Main.Showdialog() #| out-null
