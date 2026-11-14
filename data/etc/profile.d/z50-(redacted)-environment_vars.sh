hostname=$(hostname)

export country_code=$(echo "$hostname" |cut -d- -f1)
export rg_country_code=$(echo "$country_code" |tr '[:lower:]' '[:upper:]')
export region_location=$(echo "$hostname" |cut -d- -f2)
export project_name=$(echo "$hostname" |cut -d- -f3)
export environment_name=$(echo "$hostname" |cut -d- -f4)
export bastion_number=$(echo "$hostname" |sed 's/^.*[^0-9]\([0-9]*\)$/\1/')

declare subscription_id
case "$environment_name" in
    prod) subscription_id="(redacted)" ;;
    dev) subscription_id="(redacted)" ;;
    *)
        echo "ERROR: unknown subscription for environment $environment_name"
esac 
export subscription_id="$subscription_id"

export res_base_name=${country_code}-${region_location}-${project_name}-${environment_name}
export rg_base_name=${rg_country_code}-${region_location}-${project_name}-${environment_name}
export resource_group_infra=(redacted)
export resource_group_data=(redacted)
export resource_group_aks=(redacted)
export resource_group_security=(redacted)
export resource_group_monitoring=(redacted)
export resource_group_bastion=(redacted)
export resource_group_dashboards=(redacted)
