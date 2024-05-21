@{
    'Rules'         = @{
        'PSAvoidUsingCmdletAliases' = @{
            'Whitelist' = @('cd', 'foreach', 'select', 'where', 'sls')
        }
    }
    'Exclude Rules' = @('PSUseSingularNouns')
}