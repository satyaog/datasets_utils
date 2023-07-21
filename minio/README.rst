##################################
MinIO Buckets Management Utilities
##################################

********
Commands
********

``./utils.sh compute_quota_ttl``

   Compute the quota and time to live of data in a bucket based on the size of
   the data, the expected daily data upload and the minimum time to live for the
   data. Defaults can be set in the configuration file

   .. code-block:: bash

      Options for compute_quota_ttl are:
      --data-size INT expected data size in GB to be uploaded (defaults to 1000)
      --daily-quota INT expected average data size in GB to be uploaded in a day (defaults to 100)

``./utils.sh add_bucket``

   Add a bucket, compute and set the quota and time to live of the data

   .. code-block:: bash

      Options for add_bucket are:
      --name STR bucket name
      --data-size INT expected data size in GB to be uploaded (defaults to 1000)
      --daily-quota INT expected average data size in GB to be uploaded in a day (defaults to 100)
      [--alias ALIAS] MinIO server alias (defaults to 'mila-adm')
      [--mc FILE] MinIO client binary to use (defaults to 'mc')

``./utils.sh run_recipe``

   .. code-block:: bash

      Options for run_recipe are:
      --recipe STR label of the recipe to be read from 'minio/config'
      --project STR project name
      [--group STR] group name (optional)
      [--bucket STR] bucket name (optional)
      [--user STR] user name (optional)
      [--policy STR] policy name (optional)
      [--policy-template FILE] json file containing '{{TOKEN}}' placeholders to be replaced (optional)
      [--alias ALIAS] MinIO server alias (defaults to 'local')
      [--mc FILE] MinIO client binary to use (defaults to 'mc')
