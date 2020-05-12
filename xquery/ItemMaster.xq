(: This is a xquery module usable only in Basex, as some of the used functions are not available in IICS :)
declare variable $outputFile as xs:string? external:=  '/Users/jbrazda/workspace/icrt_common/halo_item_master/sample-data/DB_Output/ProcessItemMaster.xml';
declare variable $inputFile as xs:string? external:=  '../sample-data/ItemMasterImport/ItemMaster_PCSample.xml';
declare variable $lastModifiedDate as xs:dateTime? external:=  '2020-05-06T17:18:50';
declare variable $useSampleFile as xs:boolean? external:=  false();
declare variable $config as xs:string? external :=  '../config/transform_configuration.xml';




(: function to read data from DB:)
declare function local:read-from-db($db, $statement)
{
   let $input_data := sql:execute($db, $statement)
   return 
   $input_data
};


(:~ function to Initialize DB:)
declare function local:init-db($config as node()?) {
   let $class := $config/database/class/text()      (:'com.microsoft.sqlserver.jdbc.SQLServerDriver':)
   let $url := $config/database/jdbcUrl/text()      (:'jdbc:sqlserver://HBSAWS-DEV-DB01:1433;databaseName=halo_stage;':)
   let $user := $config/database/username/text()    
   let $password := $config/password/jdbcUrl/text() 
   let $statement := $config/sql/statement[@name='price_list']/text()
   let $db := sql:init($class)
   let $halo_db := sql:connect($url, $user, $password)
   return $halo_db
};


(:To read from sample file :)
declare function local:read-from-file() 
{
 for $item in doc($inputFile)/data/sql:row
    where 
    $item/sql:column[@name='Config_Code']/text() = '6'
    or $item/sql:column[@name='Config_Code']/text() = '0'
    return
    $item

};

declare function local:read-children-from-file($ParentID) 
{
 for $item in doc($inputFile)/data/sql:row
  where 
  $item/sql:column[@name='User_Defined_Field_5']/text() = $ParentID
  and $item/sql:column[@name='Config_Code']/text() = '7'
  return
  $item
};


(:~:)
declare function local:get-field-map($config as node(), $fieldName as xs:string) as item()* {
  $config/mappings/field[@name=$fieldName]/text()
};


let $configuration := doc($config)/*/.
let $db :=  if (not($useSampleFile)) then local:init-db($configuration)
let $statement := $config/sql/statement[@name='item_master_parents']/text()
let $languageID := local:get-field-map($configuration,'languageID')
let $input_data := if ($useSampleFile) then local:read-from-file() else local:read-from-db($db,$statement)

let $outputSerializationParameters := <output:serialization-parameters>
  <output:method value='xml'/>
  <output:omit-xml-declaration value='no'/>
</output:serialization-parameters>

let $DataOutput := 
<items>
   <rowCount>{count($input_data)}</rowCount>
   
   <sample>
    {(: To see sample data :) $input_data[1]} 
   </sample> 
   
   <ProcessItemMaster 
        xmlns="http://schema.infor.com/InforOAGIS/2" languageCode="{$languageID}" 
        releaseID="9.2" 
        systemEnvironmentCode="Production" versionID="2.12.2" 
        xmlns:ns0="http://schema.infor.com/InforOAGIS/2" 
        xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" 
        xsi:type="ns0:ProcessItemMasterType">
        <ApplicationArea>
            <Sender>
                <LogicalID>lid://infor.file.cim_dev</LogicalID>
                <ComponentID>Webstar</ComponentID>
                <ConfirmationCode>OnError</ConfirmationCode>
            </Sender>
            <CreationDateTime>{current-dateTime()}</CreationDateTime>
            <BODID>{random:uuid()}</BODID>
        </ApplicationArea>
        
        <DataArea>
            <Process>
                <TenantID>infor</TenantID>
                <AccountingEntityID>210_USA</AccountingEntityID>
                <ActionCriteria>
                    <ActionExpression actionCode="Add"/>
                </ActionCriteria>
            </Process>
            
            { 
            for $row at $rownum in $input_data
            let $Ext_Item_Number := $row/sql:column[@name='Ext_Item_Number']/text()
            let $Config_Code := $row/sql:column[@name='Config_Code']/text()
            return
            <ItemMaster>
                <ItemMasterHeader>
                    <ItemID>
                       <ID>{$row/sql:column[@name='Template_Item']/text()}</ID>
                    </ItemID>
                    <ID>
                         <schemeName>{$row/sql:column[@name='Name_Description']/text()}</schemeName>
 
                     </ID>
                         <Description>{$row/sql:column[@name='Name_Description_2']/text()}</Description>
                     {
                     if ( $Config_Code = '6') then
                       let $stmt_get_children := $config/sql/statement[@name='item_master_children']/text()
                       let $params := <sql:parameters>
                                         <sql:parameter type='string'>{$Ext_Item_Number}</sql:parameter>
                                       </sql:parameters>
                       let $child_items := if ($useSampleFile) 
                               then local:read-children-from-file($Ext_Item_Number)
                               else local:read-from-db($db,$stmt_get_children)
                       for $child in $child_items
                       let $ItemNumber := $child/sql:column[@name='Ext_Item_Number']/text()
                       return
                       <Specification>
                          <ID name="ITNM"
                              schemeName="{$child/sql:column[@name='Option_Size']/text()}"
                              lid="{$child/sql:column[@name='Option_Color']/text()}">
                              {$ItemNumber}
                          </ID>
                          <Property listID="">
                               <NameValue name="ITDS">{$child/sql:column[@name='Name_Description']/text()}</NameValue> 
                          </Property>                          
                        </Specification>
                     else ()
                     
                     }
                    <Specification>
                          <Description>{$row/sql:column[@name='Name_Description_2']/text()}</Description>
                          <Property listID=""><!-- Not sure about the currency field -->
                              <NameValue name="CurrencyID">{$row/sql:column[@name='Currency']/text()}</NameValue>
                          </Property>    
                    </Specification>
                    <ItemStatus>
                        <Code>10</Code>
                    </ItemStatus>
                    <BuyerPersonReference>
                        <IDs>
                            <ID>{$row/sql:column[@name='Item_Responsible']/text()}</ID>
                        </IDs>
                    </BuyerPersonReference>
                    <BaseUOMCode>{$row/sql:column[@name='Item_Basic_Unit_of_Measure']/text()}</BaseUOMCode>
                    {
                      if (empty($row/sql:column[@name='Length']/text())
                          and empty($row/sql:column[@name='Width']/text())
                          and empty($row/sql:column[@name='Height']/text())
                          and empty($row/sql:column[@name='Weight']/text())) then ()
                      else 
                    <PackagingUnit>
                        <Dimensions>
                            <LengthMeasure>{$row/sql:column[@name='Length']/text()}</LengthMeasure>
                            <WidthMeasure>{$row/sql:column[@name='Width']/text()}</WidthMeasure>
                            <HeightMeasure>{$row/sql:column[@name='Height']/text()}</HeightMeasure>
                        </Dimensions>
                        <GrossWeightMeasure>{$row/sql:column[@name='Weight']/text()}</GrossWeightMeasure>
                    </PackagingUnit>
                    }
                    
                    <UserArea>
                         <Property listID="">
                            <NameValue name="ITNE">{$Ext_Item_Number}</NameValue> 
                         </Property> 
                         <Property listID="">
                            <NameValue name="ITTY">{$row/sql:column[@name='Item_Type']/text()}</NameValue>
                         </Property>
                         <Property listID="">
                            <NameValue name="PRGP">{$row/sql:column[@name='Procurement_Group']/text()}</NameValue>
                         </Property>
                         <Property listID="">
                            <NameValue name="ITCL">{$row/sql:column[@name='Product_Group']/text()}</NameValue>
                         </Property>
                         <Property listID="">
                            <NameValue name="PDLN">{$row/sql:column[@name='Product_Line']/text()}</NameValue>
                         </Property>
                         <Property listID="">
                            <NameValue name="TAXC">{$row/sql:column[@name='Tax_Code']/text()}</NameValue>
                         </Property>
                         <Property listID="">
                            <NameValue name="RIDE">{$row/sql:column[@name='Reference_ID']/text()}</NameValue>
                         </Property>
                         <Property listID="">
                            <NameValue name="CHCD">{$row/sql:column[@name='Config_Code']/text()}</NameValue>
                         </Property>
                         <Property listID="">
                            <NameValue name="HAZI">{$row/sql:column[@name='Danger_Indicator']/text()}</NameValue>
                         </Property>
                         <Property listID="">
                            <NameValue name="CFI4">{$row/sql:column[@name='Item_Ownership']/text()}</NameValue>
                         </Property>
                         <Property listID="">
                            <NameValue name="SAPR">{$row/sql:column[@name='Sales_Price']/text()}</NameValue>
                         </Property>
                         <Property listID="">
                            <NameValue name="PRGR">{$row/sql:column[@name='Commission_Generating']/text()}</NameValue>
                         </Property>
                         <Property listID="">
                            <NameValue name="HEI1">{$row/sql:column[@name='Hierarchy_lvl_1']/text()}</NameValue>
                         </Property>
                         <Property listID="">
                            <NameValue name="HEI2">{$row/sql:column[@name='Hierarchy_lvl_2']/text()}</NameValue>
                         </Property>
                         <Property listID="">
                            <NameValue name="HEI3">{$row/sql:column[@name='Hierarchy_lvl_3']/text()}</NameValue>
                         </Property>
                         <Property listID="">
                            <NameValue name="HEI4">{$row/sql:column[@name='Hierarchy_lvl_4']/text()}</NameValue>
                         </Property>
                         <Property listID="">
                            <NameValue name="HEI5">{$row/sql:column[@name='Hierarchy_lvl_5']/text()}</NameValue>
                         </Property>
                         <Property listID="">
                            <NameValue name="GRP1">{$row/sql:column[@name='Search_Group_1']/text()}</NameValue>
                         </Property>
                         <Property listID="">
                            <NameValue name="GRP2">{$row/sql:column[@name='Search_Group_2']/text()}</NameValue>
                         </Property>
                         <Property listID="">
                            <NameValue name="GRP3">{$row/sql:column[@name='Search_Group_3']/text()}</NameValue>
                         </Property>
                         <Property listID="">
                            <NameValue name="GRP4">{$row/sql:column[@name='Search_Group_4']/text()}</NameValue>
                         </Property>
                         <Property listID="">
                            <NameValue name="GRP5">{$row/sql:column[@name='Search_Group_5']/text()}</NameValue>
                         </Property>
                         <Property listID="">
                            <NameValue name="ATMN">{$row/sql:column[@name='Attributes_Managed']/text()}</NameValue>
                         </Property>
                         <Property listID="">
                            <NameValue name="ATMO">{$row/sql:column[@name='Attribute_Model']/text()}</NameValue>
                         </Property>
                         <Property listID="">
                            <NameValue name="MABU">{$row/sql:column[@name='Make_Buy_Code']/text()}</NameValue>
                         </Property>
                         <Property listID="">
                            <NameValue name="FTID">{$row/sql:column[@name='Feature']/text()}</NameValue>
                         </Property>
                         <Property listID="">
                            <NameValue name="TPCD">{$row/sql:column[@name='Item_Category']/text()}</NameValue>
                         </Property>
                         <Property listID="">
                            <NameValue name="CFI1">{$row/sql:column[@name='Rb_Ryl_Payable']/text()}</NameValue>
                         </Property>
                         <Property listID="">
                            <NameValue name="CFI5">{$row/sql:column[@name='CSR_Follow_Up']/text()}</NameValue>
                          </Property>
                          <Property listID="">
                            <NameValue name="RESP">{$row/sql:column[@name='Planner']/text()}</NameValue>
                          </Property>
                          <Property listID="">
                            <NameValue name="LEA1">{$row/sql:column[@name='Supplier_Lead_Time']/text()}</NameValue>
                          </Property>
                          <Property listID="">
                            <NameValue name="PUIT">{$row/sql:column[@name='Acquisition_Code']/text()}</NameValue>
                          </Property>
                          <Property listID="">
                            <NameValue name="ORTY">{$row/sql:column[@name='Order_type']/text()}</NameValue>
                          </Property>
                          <Property listID="">
                            <NameValue name="SUWH">{$row/sql:column[@name='Supplying_Warehouse']/text()}</NameValue>
                          </Property>
                          <Property listID="">
                            <NameValue name="SUNO">{$row/sql:column[@name='Supplier_Code']/text()}</NameValue>
                          </Property>
                          <Property listID="">
                            <NameValue name="REOP">{$row/sql:column[@name='Reorder_Point']/text()}</NameValue>
                          </Property>
                          <Property listID="">
                            <NameValue name="EOQT">{$row/sql:column[@name='Reorder Quantity']/text()}</NameValue>
                          </Property>
                          <Property listID="">
                            <NameValue name="WHSL">{$row/sql:column[@name='Location']/text()}</NameValue>
                          </Property>
                          <Property listID="">
                            <NameValue name="BUYE">{$row/sql:column[@name='Buyer']/text()}</NameValue>
                          </Property>
                          <Property listID="">
                            <NameValue name="CSNO">{$row/sql:column[@name='Customer_Stat_Number']/text()}</NameValue>
                          </Property>
                          <Property listID="">
                            <NameValue name="FDAC">{$row/sql:column[@name='FDA_Code']/text()}</NameValue>
                          </Property>
                          <Property listID="">
                            <NameValue name="ORCO">{$row/sql:column[@name='Country_of_Origin']/text()}</NameValue>
                          </Property>
                          <Property listID="">
                            <NameValue name="REWH">{$row/sql:column[@name='Main_Warehouse']/text()}</NameValue>
                          </Property>
                      </UserArea> 
                  </ItemMasterHeader>
             </ItemMaster>
              }
        </DataArea>
    </ProcessItemMaster>
</items>
return
  (
  file:write($outputFile,
  $DataOutput/*:ProcessItemMaster,$outputSerializationParameters),$DataOutput)                   
                          
                          
                          