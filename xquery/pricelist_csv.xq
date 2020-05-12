(: This is a xquery module usable only in Basex,  as some of the used functions are not available in IICS :)
declare variable $outputFile as xs:string? external := './Csv_Output/Halo_PiceList_BOD.xml';
declare variable $inputFile as xs:string? external := './Csv_SourceFile/Halo_stgPrice_list.csv';
declare variable $lastModifiedDate as xs:dateTime? external := '2020-05-06T17:18:50';

declare variable $config as xs:string? external :=  './Config/transform_configuration.xml';


(:~ function to read data from DB:)
declare function local:read-from-db($config  as node()) as item()* {
   let $class := $config/database/class/text()      (:'com.microsoft.sqlserver.jdbc.SQLServerDriver':)
   let $url := $config/database/jdbcUrl/text()      (:'jdbc:sqlserver://HBSAWS-DEV-DB01:1433;databaseName=halo_stage;':)
   let $user := $config/database/username/text()    
   let $password := $config/password/jdbcUrl/text() 
   let $statement := $config/sql/statement[@name='price_list']/text()
   let $db := sql:init($class)
   let $halo_stage := sql:connect($url, $user, $password)
   let $sql_data := sql:execute($halo_stage,$statement )
   return 
   $sql_data
};


(:~Function to read data from sample data File:)
declare function local:read-from-file($fileFormat as xs:string) as item()* {
  switch ($fileFormat) 
  case 'csv' return local:read-from-csv()
  default return doc($inputFile)/data/sql:row

};

(:~:)
declare function local:read-from-csv() {
  (:Read and parse CSV File:)
  let $text := file:read-text($inputFile,'UTF-8',true())
  return csv:parse($text, map { 'header': true() })
};

(:~:)
declare function local:get-field-map($config as node(), $fieldName as xs:string) as item()* {
  $config/mappings/field[@name=$fieldName]/text()
};

(:~:)
declare function local:get-record-field() {
  
  
};

let $configuration := doc($config)/*/.
let $useSampleFile := $configuration/use-sample-input/text() = 'true'
let $fileFormat  := $configuration/sample-input-format/text()  

let $input_data := if ($useSampleFile) 
                    then local:read-from-file($fileFormat) 
                    else local:read-from-db($configuration)

let $outputSerializationParameters := <output:serialization-parameters>
  <output:method value='xml'/>
  <output:omit-xml-declaration value='no'/>
</output:serialization-parameters>


let $languageID := local:get-field-map($configuration,'languageID')

let $DataOutput := 
<items>
    <rowCount>{count($input_data/csv/record)}</rowCount>
    <sample>
      {$input_data/csv/record[1]}
    </sample>
    <PriceList 
        xmlns="http://schema.infor.com/InforOAGIS/2" languageCode="GB" 
        releaseID="9.2" 
        systemEnvironmentCode="Production" 
        versionID="2.12.2" 
        xmlns:ns0="http://schema.infor.com/InforOAGIS/2" 
        xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" 
        xsi:type="ns0:ProcessItemMasterType">
        <ApplicationArea>
            <Sender>
                <LogicalID>{local:get-field-map($configuration,'LogicalID')}</LogicalID>
                <ComponentID>Webstar</ComponentID>
                <ConfirmationCode>OnError</ConfirmationCode>
                <AuthorizationID></AuthorizationID>
            </Sender>
            <CreationDateTime>{current-dateTime()}</CreationDateTime>
        </ApplicationArea>
        <DataArea>
            <Sync>
                <TenantID>Infor</TenantID>
                <AccountingEntityID>{local:get-field-map($configuration,'AccountingEntityID')}</AccountingEntityID>
                <LocationID>loc123</LocationID>
                <ActionCriteria> 
                    <!-- initial Load should be 'Add' and updates should use Update -->
                    <ActionExpression actionCode="Add" expressionLanguage=""/>
                </ActionCriteria>
            </Sync>            
            { (: implement Group By using Priceslist :)  
            
            for $catalog at $rownum in $input_data/*:csv/*:record
               group by $catalogName := $catalog/*:Price_List
            return
            <Catalog>
                <CatalogHeader>          
                    <Name languageID="{$languageID}">{$catalogName}</Name>
                </CatalogHeader>
                { (: loop over lines in group :)  
                for $record at $rownum in $catalog
                group by $Ext_Item_Number := $record/*:Ext_Item_Number, $name := $record/*:Name
                return
                <CatalogLine>
                    <Item>
                        <ItemID>
                            <ID schemeName="{$name}">{$Ext_Item_Number}</ID>
                        </ItemID>       
                        <Description languageID="{$languageID}">{$record[1]/*:Description/text()}</Description>
                    </Item>
                    <TimePeriod>
                        <StartDateTime>{$record[1]/*:Valid_From/text()}</StartDateTime>
                        <EndDateTime>{$record[1]/*:Valid_To/text()}</EndDateTime>
                    </TimePeriod>
                    {for $price in $record
                    return
                    <ItemPrice>
                        <UnitPrice>
                            <Amount currencyID="USD">{$price/*:Sales_Price_Detail1/text()}</Amount>
                            <BaseAmount currencyID="USD">{$price/*:Sales_Price/text()}</BaseAmount>
                            <PerQuantity unitCode="EA">{$price/*:Quantity/text()}</PerQuantity>
                            <PerBaseUOMQuantity unitCode="EA">{$price/*:Sales_Price_UM/text()}</PerBaseUOMQuantity>
                        </UnitPrice>
                        <Note languageID="{$languageID}"></Note>
                    </ItemPrice>
                  }
                </CatalogLine>  
              }
            </Catalog>
          }
        </DataArea>
    </PriceList>
</items>
return
  (
  file:write($outputFile,
  $DataOutput/*:PriceList,$outputSerializationParameters),$DataOutput)
