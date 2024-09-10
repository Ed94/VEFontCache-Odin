function clone-gitrepo { param( [string] $path, [string] $url )
	if (test-path $path) {
		# git -C $path pull
	}
	else {
		Write-Host "Cloning $url ..."
		git clone $url $path
	}
}
function Get-IniContent { param( [string] $path_file )
	$ini            = @{}
	$currentSection = $null
	switch -regex -file $path_file
	{
		"^\[(.+)\]$" {
			$currentSection       = $matches[1].Trim()
			$ini[ $currentSection ] = @{}
		}
		"^(.+?)\s*=\s*(.*)" {
			$key, $value = $matches[1].Trim(), $matches[2].Trim()
			if ($null -ne $currentSection) {
				$ini[ $currentSection ][ $key ] = $value
			}
		}
	}
	return $ini
}

# TODO(Ed): This is garbage for odin's output..
function Invoke-WithColorCodedOutput { param( [scriptblock] $command )
	& $command 2>&1 | ForEach-Object {
		# Write-Host "Type: $($_.GetType().FullName)" # Add this line for debugging
		$color = 'White' # Default text color
		switch ($_) {
			{ $_ -imatch "error" } { $color = 'Red'; break }
			{ $_ -imatch "warning" } { $color = 'Yellow'; break }
		}
		Write-Host "`t$_" -ForegroundColor $color
	}
}
function Update-GitRepo
{
	param( [string] $path, [string] $url, [string] $build_command )

	if ( $build_command -eq $null ) {
		write-host "Attempted to call Update-GitRepo without build_command specified"
		return
	}

	$repo_name = $url.Split('/')[-1].Replace('.git', '')

	$last_built_commit = join-path $path_build "last_built_commit_$repo_name.txt"
	if ( -not(test-path -Path $path))
	{
		write-host "Cloining repo from $url to $path"
		git clone $url $path

		write-host "Building $url"
		push-location $path
		& "$build_command"
		pop-location

		git -C $path rev-parse HEAD | out-file $last_built_commit
		$script:binaries_dirty = $true
		write-host
		return
	}

	git -C $path fetch
	$latest_commit_hash = git -C $path rev-parse '@{u}'
	$last_built_hash    = if (Test-Path $last_built_commit) { Get-Content $last_built_commit } else { "" }

	if ( $latest_commit_hash -eq $last_built_hash ) {
		write-host
		return
	}

	write-host "Build out of date for: $path, updating"
	write-host 'Pulling...'
	git -C $path pull

	write-host "Building $url"
	push-location $path
	& $build_command
	pop-location

	$latest_commit_hash | out-file $last_built_commit
	$script:binaries_dirty = $true
	write-host
}

function verify-path { param( $path )
	if (test-path $path) {return $true}

	new-item -ItemType Directory -Path $path
	return $false
}
