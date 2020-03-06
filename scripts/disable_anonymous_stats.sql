/*
*		This script disables anonymous access to variable statistics by:
*		- Disabling anonymous access to variable statistics
*		- Inserting mica routes in 'cmp_menu_perms' MySQL table
*		- Enabling redirection of anonymous users to login page
*		Note: requires custom_menu_perms module to be enebled
*/

-- Disable anonymous access to published content
DELETE FROM role_permission WHERE rid="1" AND permission="access content" AND module="node";
-- (same as unticking 'anonymous' for 'View published content' in 'People' -> 'Permissions')

-- Insert mica routes in 'cmp_menu_perms' MySQL table
REPLACE INTO cmp_menu_perms
	(menu_path, cmp_permission_key)
VALUES
	-- ('mica/get_fixed_sidebar/%','access content'),
	-- ('mica/datatable-international','access content'),
	-- ('mica/dataset','access content'),
	-- ('mica/dataset/harmonized-dataset','access content'),
	-- ('mica/dataset/collected-dataset','access content'),
	-- ('variable-detail-statistics/%','access content'),
	-- ('mica/collected-dataset/%','access content'),
	-- ('mica/collected-dataset/%/draft/%','access content'),
	-- ('mica/harmonized-dataset/%','access content'),
	-- ('mica/harmonized-dataset/%/draft/%','access content'),
	('mica/%/%/variables/%/%/ws','access content'),
	('mica/%/%/variables/%/ws','access content'),
	-- ('mica/%/%/variables/cross/%/by/%/ws','access content'),
	-- ('mica/%/%/download_csv/cross/%/by/%/ws','access content'),
	-- ('mica/%/%/download_excel/cross/%/by/%/ws','access content'),
	-- ('mica/variable/%/ws','access content'),
	-- ('mica/dataset/%/%/ws','access content'),
	-- ('mica/variables-tab/%/%','access content'),
	-- ('mica/variables-tab-data/%/%','access content'),
	-- ('mica/variables-tab-header/%/%','access content'),
	-- ('mica/variables-harmonization-algo/%/%','access content'),
	-- ('mica/harmonized-dataset/%/download','access content'),
	('mica/variable/%','access content');
	-- ('mica/ng/coverage/dataset/%','access content'),
	-- ('mica/ng/coverage/variable/%','access content'),
	-- ('mica/data_access','access content'),
	-- ('mica/data_access/home','access content'),
	-- ('mica/data_access/requests/ws','access content'),
	-- ('mica/data_access/requests/csv/ws','access content'),
	-- ('mica/data_access/request/%/comments/ws','access content'),
	-- ('mica/data_access/request/%/comment/%/ws','access content'),
	-- ('mica/data_access/request/%/_pdf/ws','access content'),
	-- ('mica/data_access/request/%/attachments/%/_download/ws','access content'),
	-- ('mica/data_access/request/form/attachments/%/%/_download/ws','access content'),
	-- ('mica/data_access/request/%/_status/%/ws','access content'),
	-- ('mica/data_access/request/upload-file','access content'),
	-- ('mica/data_access/request/%/ws','access content'),
	-- ('mica/data_access/request/%/_attachments/ws','access content'),
	-- ('mica/data_access/request/file/%','access content'),
	-- ('mica/data_access/data-access-form/ws','access content'),
	-- ('mica/data_access/request/delete/%/ws','access content'),
	-- ('mica/data_access/request/redirect/%/%','access content'),
	-- ('mica/data_access/user/%/ws','access content'),
	-- ('mica/data_access/users/ws','access content'),
	-- ('mica/data_access/users','access content'),
	-- ('download/%/%/%','access content'),
	-- ('mica/file','access content'),
	-- ('mica/files/search','access content'),
	-- ('mica/file/download','access content'),
	-- ('mica/networks','access content'),
	-- ('mica/network/%','access content'),
	-- ('mica/network/%/draft/%','access content'),
	-- ('mica/ng/coverage/network/%','access content'),
	-- ('mica/persons/%/ws','access content'),
	-- ('mica/persons/%/download/ws','access content'),
	-- ('mica/repository/taxonomies/_search/ws','access content'),
	-- ('mica/repository/taxonomies/_filter/ws','access content'),
	-- ('mica/repository/%/_rql/%/ws','access content'),
	-- ('mica/repository/%/_rql_csv/%/ws','access content'),
	-- ('mica/repository/variables/_coverage/%/ws','access content'),
	-- ('mica/repository/variables/_coverage_download/%/ws','access content'),
	-- ('mica/repository/taxonomy/%/_filter/ws','access content'),
	-- ('mica/research','access content'),
	-- ('mica/research/projects','access content'),
	-- ('mica/project/%','access content'),
	-- ('mica/project/%/draft/%','access content'),
	-- ('mica/study','access content'),
	-- ('mica/study/individual-study','access content'),
	-- ('mica/individual-study/%/networks','access content'),
	-- ('mica/individual-study/%/datasets','access content'),
	-- ('mica/individual-study/%','access content'),
	-- ('mica/individual-study/%/draft/%','access content'),
	-- ('mica/study/harmonization-study','access content'),
	-- ('mica/harmonization-study/%','access content'),
	-- ('mica/harmonization-study/%/draft/%','access content'),
	-- ('mica/harmonization-study/%/networks','access content'),
	-- ('mica/harmonization-study/%/datasets','access content'),
	-- ('mica/ng/coverage/%/%','access content');

-- Enable redirection of anonymous users to login page
REPLACE INTO variable VALUES ("site_403","s:10:\"user/login\";");
-- (this will only work for native Drupal published pages and for every route in the cmp_menu_perms table)
