USE [Antsprodlive]
GO
/****** Object:  StoredProcedure [dbo].[@INSPL_Sales_TN_ARInvoice]    Script Date: 29-08-2021 10:29:45 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[@INSPL_Sales_TN_ARInvoice] (@DocEntry AS NVARCHAR(20))
AS
BEGIN
	DECLARE @ErrorCode AS INT -- Result (0 for no error)   
	DECLARE @ErrorName AS NVARCHAR(max) -- Error string to be displayed   
	DECLARE @Type AS NVARCHAR(20)
	DECLARE @ItemCode AS NVARCHAR(20)

	SET @ErrorCode = 0
	SET @ErrorName = ''

	--=============================================================================================   
	------------------------AR Invoice ------------------------------------------------  
	IF EXISTS (
			SELECT T0.DocEntry
			FROM dbo.Oinv T0 WITH (NOLOCK)
			INNER JOIN INV1  T1 ON t0.DocEntry = t1.DocEntry
			LEFT JOIN NNM1 b With (NoLock)  ON b.Series = T0.Series AND Left(b.SeriesName, 2) <> 'SS'
			LEFT JOIN oitm c With (NoLock)  ON t1.ItemCode = c.ItemCode 
			WHERE   t1.U_NoofPiece <> t1.Quantity 	AND T0.DocEntry = @DocEntry AND c.ItmsGrpCod NOT IN ('102')
				
			)
		SELECT @ErrorCode = 10 ,@ErrorName = 'No.Of.Piece & QuantitY Should not Equal'

		 

	IF EXISTS (
			SELECT a.DocEntry 
			FROM [Oinv] A WITH (NOLOCK)
			INNER JOIN [inv1] B WITH (NOLOCK) ON A.DocEntry = B.DocEntry
			WHERE b.DiscPrcnt <> 0
				AND a.UserSign2 IN (4,5,6,32)
				AND A.DocEntry = @DocEntry
			)
		SELECT @ErrorCode = 10 ,@ErrorName = 'Discount Not allowed in the item row'

	IF EXISTS (
			SELECT a.DocEntry
			FROM RDR1 a WITH (NOLOCK)
			INNER JOIN (
				SELECT c.DocEntry
					,c.LineNum
					,sum(b.Quantity) InvQty
				FROM oinv a WITH (NOLOCK)
				INNER JOIN (
					SELECT DocEntry
						,U_BLineNum
						,baseline
						,U_BDocENtry
						,BaseEntry
						,ItemCode
						,BaseType
						,Quantity
					FROM inv1 WITH (NOLOCK)
					) b ON a.docentry = b.docentry
				LEFT JOIN (
					SELECT DocEntry
						,LineNum
						,LineStatus
					FROM DLN1 WITH (NOLOCK)
					) c ON c.docentry = isnull(b.U_BDocENtry, b.BaseEntry)
				LEFT JOIN (
					SELECT Series
						,SeriesName
					FROM NNM1 WITH (NOLOCK)
					) sn ON sn.Series = a.Series
				WHERE LEFT(sn.seriesname, 2) = 'SS'
					AND isnull(b.U_BLineNum, b.baseline) = c.LineNum
					AND b.BaseType IN ('15')
					AND c.DocEntry IN (
						SELECT U_BDocENtry
						FROM INV1 WITH (NOLOCK)
						WHERE ISNULL(U_BDocENtry, '') <> ''
							AND DocEntry = @docentry
							AND BaseType IN ('15')
						)
					AND b.ItemCode <> 'FreightCharges'
					AND c.LineStatus <> 'C'
				GROUP BY c.DocEntry
					,c.LineNum
				) b ON a.DocEntry = b.DocEntry
				AND a.LineNum = b.LineNum
			WHERE a.Quantity < b.InvQty
			)
		SELECT @ErrorCode = 1001
			,@ErrorName = 'Sales Invoice Quantity Should Not Be Greater Then Sale Order Quantity......' + @ItemCode

	SET @ItemCode = (
			SELECT TOP 1 b.ItemCode
			FROM OINV a WITH (NOLOCK)
			INNER JOIN inv1 b WITH (NOLOCK) ON a.DocEntry = b.DocEntry
			LEFT JOIN NNM1 c WITH (NOLOCK) ON c.Series = a.Series
			WHERE a.DocEntry = @DocEntry
				AND LEFT(c.SeriesName, 2) = 'SS'
			GROUP BY a.DocEntry
				,a.DocNum
				,ItemCode
			HAVING count(b.ItemCode) > 1
			)

 	IF EXISTS (
			SELECT a.DocEntry
			FROM DLN1 a WITH (NOLOCK)
			INNER JOIN (
				SELECT c.DocEntry
					,c.LineNum
					,sum(b.Quantity) InvQty
				FROM oinv a WITH (NOLOCK)
					,inv1 b WITH (NOLOCK)
					,dln1 c WITH (NOLOCK)
					,NNM1 sn WITH (NOLOCK)
				WHERE sn.Series = a.Series
					AND LEFT(sn.seriesname, 2) = 'SS'
					AND a.docentry = b.docentry
					AND c.docentry = b.BaseEntry
					AND b.BaseLine = c.LineNum
					AND b.BaseType IN ('15')
					AND c.DocEntry IN (
						SELECT BaseEntry
						FROM INV1 With (NoLock) 
						WHERE ISNULL(BaseEntry, '') <> ''
							AND DocEntry = @docentry
							AND BaseType IN ('15')
						)
				GROUP BY c.DocEntry
					,c.LineNum
				) b ON a.DocEntry = b.DocEntry
				AND a.LineNum = b.LineNum
			WHERE a.Quantity < b.InvQty
			)
		SELECT @ErrorCode = 1001
			,@ErrorName = 'Invoice Quantity Should Not Be Greater Then Delivery Quantity......' + @ItemCode

	SET @ItemCode = (
			SELECT a.DocEntry
			FROM DLN1 a WITH (NOLOCK)
			INNER JOIN (
				SELECT c.DocEntry
					,c.LineNum
					,sum(b.Quantity) InvQty
				FROM oinv a WITH (NOLOCK)
					,inv1 b WITH (NOLOCK)
					,dln1 c WITH (NOLOCK)
					,NNM1 sn WITH (NOLOCK)
				WHERE sn.Series = a.Series
					AND LEFT(sn.seriesname, 2) = 'SS'
					AND a.docentry = b.docentry
					AND c.docentry = b.BaseEntry
					AND b.BaseLine = c.LineNum
					AND b.BaseType IN ('15')
					AND c.DocEntry IN (
						SELECT BaseEntry
						FROM INV1 WITH (NOLOCK)
						WHERE ISNULL(BaseEntry, '') <> ''
							AND DocEntry = @docentry
							AND BaseType IN ('15')
						)
					AND b.ItemCode <> 'FreightCharges'
				GROUP BY c.DocEntry
					,c.LineNum
				) b ON a.DocEntry = b.DocEntry
				AND a.LineNum = b.LineNum
			WHERE a.Quantity <> b.InvQty
			)

	IF EXISTS (
			SELECT a.DocEntry
			FROM DLN1 a WITH (NOLOCK)
			INNER JOIN (
				SELECT c.DocEntry
					,c.LineNum
					,sum(b.Quantity) InvQty
				FROM oinv a WITH (NOLOCK)
					,inv1 b WITH (NOLOCK)
					,dln1 c WITH (NOLOCK)
					,NNM1 sn WITH (NOLOCK)
				WHERE sn.Series = a.Series
					AND LEFT(sn.seriesname, 2) = 'SS'
					AND a.docentry = b.docentry
					AND c.docentry = b.BaseEntry
					AND b.BaseLine = c.LineNum
					AND b.BaseType IN ('15')
					AND c.DocEntry IN (
						SELECT BaseEntry
						FROM INV1 WITH (NOLOCK)
						WHERE ISNULL(BaseEntry, '') <> ''
							AND DocEntry = @docentry
							AND BaseType IN ('15')
						)
				GROUP BY c.DocEntry
					,c.LineNum
				) b ON a.DocEntry = b.DocEntry
				AND a.LineNum = b.LineNum
			WHERE a.Quantity <> b.InvQty
			)
		SELECT @ErrorCode = 1001
			,@ErrorName = 'Invoice Quantity Should Not Be Match Delivery Quantity......' + @ItemCode

	-- If Exists(        
	--  Select  * From  inv12 A, OINV B  Where a.DocEntry=b.docentry  
	--And ISNULL(A.TaxId11,'') = ''  And B.CardCode is not null   and B.DocEntry=@DocEntry )             
	--  SELECT  @ErrorCode=10 , @ErrorName = 'Please Check BP Master TIN NO is Missing..................'   
	IF EXISTS (
			SELECT a.DocEntry,a.usersign,a.Series
			FROM [OINV] a WITH (NOLOCK)
			LEFT JOIN nnm1 b WITH (NOLOCK) ON A.Series=B.Series
			WHERE LEFT(b.seriesname, 2) NOT IN ('PR')
				AND usersign IN (4,5,6,30,32,112)
				AND a.DocEntry = @DocEntry
			)
		SELECT @ErrorCode = 10,@ErrorName = 'Check Docnument Numbering Series '

	IF EXISTS (
			SELECT a.DocEntry,a.CardCode,a.series
			FROM [OINV] a WITH (NOLOCK)
			LEFT JOIN nnm1 b WITH (NOLOCK) ON A.Series=B.Series
			WHERE LEFT(b.seriesname, 2) NOT IN ('CS')
				AND CardCode = 'C037724'
				AND a.DocEntry = @DocEntry
			)
		SELECT @ErrorCode = 10
			,@ErrorName = 'Check Docnument Numbering Series '

	IF EXISTS (
			SELECT a.DocEntry,a.CardCode,a.series
			FROM oinv a WITH (NOLOCK)
			LEFT JOIN (
				SELECT CardCode
					,GroupCode
					,QryGroup1
				FROM ocrd WITH (NOLOCK)
				) b ON a.CardCode = b.CardCode
			LEFT JOIN (
				SELECT Series
					,SeriesName
				FROM nnm1 WITH (NOLOCK)
				) c ON A.Series = c.Series
			WHERE b.GroupCode = '112'
				AND A.DocEntry = @DocEntry
				AND b.QryGroup1 = 'Y'
				AND left(c.SeriesName, 2) = 'SS'
			)
		SELECT @ErrorCode = 9
			,@ErrorName = 'Document Series is Mismatch'

	--  If Exists(  Select a.Type,a.DocEntry,a.DocNum,a.DocDate,a.DocTime,
	--replace(convert(char(5),cast(a.SysTime as datetime),108),':','') SysTime,
	--	a.CardCode,a.CardName,a.U_Brand,a.DocType,a.Irn from 
	--	(Select  'INV' Type,a.DocEntry,a.DocNum,a.DocDate,A.DocTime,
	--	LTRIM(RIGHT(CONVERT(VARCHAR(20), GETDATE(), 100), 7))SysTime,
	--	a.CardCode,a.CardName,a.U_Brand,a.DocType,b.Irn from oinv a with (nolock)
	--	left join EInvoice b with (nolock) on a.DocEntry=b.DocEntry  
	--	left join ocrd d with (nolock) on d.CardCode=a.CardCode
	--	left join nnm1 c with (nolock) on c.Series=a.Series
	--	where a.DocEntry not in (select DocEntry from EInvoice with (nolock) where DocType='INV') and a.DocDate>='20201001'  and a.CANCELED='N' 
	--	and d.U_GSTIN not in ('33AAIFA8010E1Z1','UNREGISTERED') 
	--	and a.CardCode not in ('C037724','C028971') and left(c.SeriesName,2)='SS')a
	--	Where convert(int,a.DocTime)+15<convert(int,replace(convert(char(5),cast(a.SysTime as datetime),108),':',''))
	--	and a.DocEntry=@DocEntry )
	--	SELECT  @ErrorCode=9 , @ErrorName = 'Please Generate IRN for Older Invoice or CN. Contact to Saravanan...' 
	--if exists(  
	-- select a.DocNum from Oinv a WITH(NOLOCK),inv1 b WITH(NOLOCK) ,CRD1 c WITH(NOLOCK), nnm1 ss WITH(NOLOCK),  
	--  (SELECT BB.DocEntry, BB.LINENUM,LL.STATE,BB.ITEMCODE,IT.U_STCODE,IT.U_ITCODE,  
	--   case when  LL.STATE='TN' THEN  
	--    CASE WHEN BB.PRICE>1000 THEN   
	--      ltrim(rtrim(IT.u_stcode))+ltrim(rtrim(IT.u_taxrate1000))  
	--     ELSE  
	--      ltrim(rtrim(IT.u_stcode))+ltrim(rtrim(IT.u_taxrate))   
	--     END   
	--   else   
	--          case when  BB.PRICE >1000 then   
	--           ltrim(rtrim(IT.u_itcode))+ltrim(rtrim(IT.u_taxrate1000))  
	--            else   
	--           ltrim(rtrim(IT.u_itcode))+ltrim(rtrim(IT.u_taxrate))   
	--          end   
	--         end AS TAXCODE  
	--      FROM INV1 BB WITH(NOLOCK) ,OINV CC WITH(NOLOCK),CRD1 LL WITH(NOLOCK),OITM IT WITH(NOLOCK) WHERE BB.DocEntry=CC.DocEntry AND CC.CardCode= LL.CARDCODE AND BB.ItemCode=IT.ItemCode  
	--      AND LL.AdresType='B' AND  BB.DocEntry=@DocEntry ) TT      
	--    where a.DocEntry=b.DocEntry and a.CardCode=c.CardCode  and a.DocEntry=@DocEntry  and c.Address=A.PayToCode
	--    and  ss.series = a.series  And left(ss.Seriesname,2) = 'SS'  
	--    AND A.DOCENTRY=TT.DOCENTRY AND B.LINENUM=TT.LINENUM AND B.ITEMCODE=TT.ITEMCODE AND B.TAXCODE<> TT.TAXCODE AND C.STATE=TT.STATE)  
	--  SELECT  @ErrorCode=11 , @ErrorName = 'GST TaxCode Mismatch'
	IF EXISTS (
			SELECT a.DocEntry,a.doctype,a.Series,a.UserSign2
			FROM OINV A WITH (NOLOCK)
			INNER JOIN (
				SELECT DISTINCT DocEntry
					,BaseType
					,Dscription
				FROM inv1 WITH (NOLOCK)
				) b ON a.DocEntry = b.DocEntry
			LEFT JOIN (
				SELECT Series
					,SeriesName
				FROM nnm1 WITH (NOLOCK)
				) c ON c.Series = a.Series
			WHERE b.BaseType = '17'
				AND a.DocType <> 'S'
				AND left(c.SeriesName, 2) = 'SS'
				AND B.Dscription NOT LIKE '%WASTE%'
				AND A.DocEntry = @DocEntry
				--And UserSign Not in (3) 
				AND a.UserSign2 <> '98'
			)
		SELECT @ErrorCode = 27
			,@ErrorName = 'Please Put it on Delivery'

	IF EXISTS (
			SELECT a.DocEntry,a.DiscPrcnt
			FROM OINV A WITH (NOLOCK)
			WHERE A.DiscPrcnt <> 0
				AND A.DocEntry = @DocEntry
			)
		SELECT @ErrorCode = 27
			,@ErrorName = 'DO NOT GIVE THE DISCOUNT  IN  FOOTER LIST ..............'

	IF EXISTS (
			SELECT a.DocEntry,a.taxcode
			FROM INV3 A WITH (NOLOCK)
			WHERE A.TaxCode NOT IN (
					SELECT TOP 1 TAXCODE
					FROM INV1 WITH (NOLOCK)
					WHERE DocEntry = @DocEntry
					GROUP BY TaxCode
					HAVING MAX(convert(INT, SUBSTRING(TaxCode, PATINDEX('%[0-9]%', TaxCode), LEN(TaxCode)))) > 0
					ORDER BY TaxCode
					)
				AND A.DocEntry = @DocEntry
			)
		SELECT @ErrorCode = 28
			,@ErrorName = 'FREIGTH CHARGE TAX CODE WRONG ..............'

	IF EXISTS (
			SELECT t0.DocEntry
			FROM OINV t0 WITH (NOLOCK)
			INNER JOIN INV1 t1 WITH (NOLOCK) ON T0.DocEntry=T1.DocEntry
			WHERE TreeType <> 'I'
				AND t0.DocEntry = @DocEntry
				AND isnull(U_HSNCODE, '') = ''
				AND isnull(U_SACCODE, '') = ''
			)
		SELECT @ErrorCode = 2
			,@ErrorName = 'HSN / SAC Code is Empty.....'

	IF EXISTS (
			SELECT DISTINCT a.DocEntry
			FROM oinv a WITH (NOLOCK)
			INNER JOIN inv1 b WITH (NOLOCK) ON a.DocEntry = b.DocEntry
			LEFT JOIN nnm1 c WITH (NOLOCK) ON A.Series = c.Series
			WHERE a.DocEntry = @DocEntry
				AND len(U_HSNCODE) <> 8
				AND a.CANCELED = 'N'
				AND left(c.SeriesName, 2) <> 'CS'
				AND a.DocDate >= '20210401'
			)
		SELECT @ErrorCode = 2
			,@ErrorName = 'The HSNCODE Must be Eight Digits Long....'

	IF EXISTS (
			SELECT t0.DocEntry
			FROM OINV t0 WITH (NOLOCK)
			INNER JOIN INV1 t1 WITH (NOLOCK) ON T0.DocEntry=T1.DocEntry
			WHERE DocType <> 'I'
				AND t0.DocEntry = @DocEntry 
				AND LEN(isnull(U_SACCODE, 0)) < 6
				AND t0.DocDate >= '20210401'
			)
		SELECT @ErrorCode = 2
			,@ErrorName = 'The SACCODE Must be Equals or Below Six Digits Long....'

	IF EXISTS (
			SELECT a.DocEntry,a.u_ordtype
			FROM OINV A WITH (NOLOCK)
			INNER JOIN INV1 B WITH (NOLOCK) ON A.DocEntry = B.DocEntry
			WHERE A.CardCode IS NOT NULL
				AND isnull(B.TaxCode, '') = ''
				AND A.DocEntry = @DocEntry
				AND a.U_OrdType <> 'AO'
			)
		SELECT @ErrorCode = 10
			,@ErrorName = 'TaxCode Should Not Be Left Empty'

	IF EXISTS (
			SELECT c.DocEntry,c.U_Brand,c.U_Type
			FROM [INV1] b WITH (NOLOCK)
			INNER JOIN OINV c WITH (NOLOCK) ON B.DocEntry=C.DocEntry
			WHERE ISNULL(b.U_BDocENtry, '') = ''
			AND c.CardCode<>'C037724'
				AND ISNULL(b.Baseentry, '') = ''
				AND ISNULL(C.U_BRAND, '') <> ''
				AND b.DocEntry = @DocEntry
				AND b.ItemCode <> 'FrightCharges')
		SELECT @ErrorCode = 1300
			,@ErrorName = 'Base Document Should not be left empty......'

	
	IF EXISTS (
			SELECT c.docentry,c.U_Type 
			FROM [INV1] b WITH (NOLOCK)
			INNER JOIN	OINV c WITH (NOLOCK) ON B.DocEntry=C.DocEntry
			WHERE c.CardCode<>'C037724'
				AND b.U_BLineNum = ''
				AND b.BaseLine = ''
				AND b.DocEntry = @DocEntry
				AND b.ItemCode <> 'FrightCharges')
		SELECT @ErrorCode = 1301
			,@ErrorName = 'Base Document Line No  Should not be left empty......'

	IF EXISTS (
			SELECT a.DocEntry,a.UserSign
			FROM [OINV] A WITH (NOLOCK)
			INNER JOIN [INV1] B WITH (NOLOCK) ON A.DocEntry = B.DocEntry
			INNER JOIN OWHS c WITH (NOLOCK) ON b.WhsCode = c.WhsCode
			WHERE A.DocEntry = @DocEntry
				AND c.DropShip = 'Y'
				AND a.UserSign NOT IN ('48','1') )
		SELECT @ErrorCode = 10
			,@ErrorName = 'There is no Rights to Make Supplementory Invoice'

	IF EXISTS (
			SELECT a.DocEntry,a.Series
			FROM [OINV] A WITH (NOLOCK)
			INNER JOIN [INV1] B WITH (NOLOCK) ON A.DocEntry = B.DocEntry
			INNER JOIN OWHS c With (NoLock)  ON b.WhsCode = c.WhsCode
			WHERE A.DocEntry = @DocEntry
				AND c.DropShip = 'Y'
				AND a.Series NOT IN ('86') )
		SELECT @ErrorCode = 10
			,@ErrorName = 'Document Series is Mismatch'

	--  if exists(
	--select a.DocNum from ORDR a  WITH (NOLOCK) where a.DocEntry=@DocEntry  and isnull(a.Address,'') = '' and isnull(a.Address2,'') = '') 
	--SELECT  @ErrorCode=11 , @ErrorName = 'Address Should Not Be Empty........'
	IF EXISTS (
			SELECT a.DocEntry,a.U_Type,a.UserSign
			FROM INV1 b
			INNER JOIN OINV a WITH (NOLOCK) ON B.DocEntry=A.DocEntry
			INNER JOIN OUSR c WITH (NOLOCK) ON A.UserSign=C.USERID
			WHERE c.department IN (- 2)
				AND a.U_Type <> 'C'
				AND (
					len(rtrim(ltrim(isnull(b.OcrCode5, '')))) = 0
					OR b.OcrCode5 IS NULL
					)
				AND a.DocEntry = @Docentry
			)
		SELECT @ErrorCode = 105
			,@ErrorName = 'Select Company Unit(Mkt or Prod or Outlet)'


	------------- Regular Invoice Validations   
	IF NOT EXISTS (
			SELECT CASE 
					WHEN datediff(dd, docdate, getdate()) <> 0
						THEN 'Error'
					END AS t
			FROM OINV WITH (NOLOCK)
			WHERE DocEntry = @DocEntry
			)
	BEGIN
		SELECT @ErrorCode = 10
			,@ErrorName = 'Document Date and Delivery Date must Match'
	END

	IF NOT EXISTS (
			SELECT a.DocEntry,a.WhsCode
			FROM INV1 a WITH (NOLOCK)
			INNER JOIN OWHS b WITH (NOLOCK) ON A.WhsCode=B.WhsCode
			WHERE b.DropShip = 'Y'
				AND a.DocEntry = @DocEntry )
	BEGIN
		IF EXISTS (
				SELECT a.DocEntry,a.U_Type,a.cardcode
				FROM [OINV] A WITH (NOLOCK)
				INNER JOIN [INV1] B WITH (NOLOCK) ON A.DocEntry = B.DocEntry
				LEFT JOIN [OITM] c ON c.ItemCode = b.ItemCode
				WHERE B.U_Size IS NULL
					AND B.U_CatalogName IS NOT NULL
					AND a.U_Type NOT IN ('C037724')
					AND A.DocEntry = @DocEntry
					AND c.ItmsGrpCod NOT IN (138)
					AND A.CardCode <> 'C029075'
				)
			SELECT @ErrorCode = 10
				,@ErrorName = 'Size should not be left Empty'

		IF EXISTS (
				SELECT DISTINCT A.DocEntry
					,A.DocNum
					,A.DocDate
					,a.CardCode
					,a.CardName
				FROM OINV A With (NoLock) 
				INNER JOIN INV1 B With (NoLock)  ON A.DocEntry = B.DocEntry
				WHERE ISNULL(B.U_CatalogName, '') = ''
					AND a.DocEntry = @DocEntry
					AND ISNULL(A.U_Brand, '') <> ''
					AND a.CANCELED = 'N'
					AND a.DocType = 'I'
				)
			SELECT @ErrorCode = 10
				,@ErrorName = 'Brand should not be selected for this type of Invoice. Please Clear the Brand'

		IF EXISTS (
				SELECT a.DocEntry,a.Series,a.CANCELED,a.U_OrdType,*
				FROM oinv a WITH (NOLOCK)
				INNER JOIN INV1 b ON a.DocEntry = b.DocEntry
				inner JOIN NNM1 c ON c.Series = a.Series
				WHERE isnull(U_FreeQty, 0) > 0
					AND a.CANCELED = 'N'
					AND a.U_OrdType not in ('SO')
					AND a.DocEntry = @DocEntry
					AND left(c.SeriesName, 2) = 'SS'
				)
			SELECT @ErrorCode = 10
				,@ErrorName = 'Select Order Type on Scheme Order'

		--IF NOT EXISTS (
		--		SELECT a.docentry,a.ItemCode,a.quantity
		--		FROM INV1 A WITH (NOLOCK)
		--			,OITW B WITH (NOLOCK)
		--		WHERE A.ItemCode = B.ItemCode
		--			AND B.OnHand >= A.Quantity
		--		)
		--	SELECT @ErrorCode = 10
		--		,@ErrorName = 'Stock there is no hand please check....'

		IF NOT EXISTS (
				SELECT c.docentry,c.cardcode
				FROM OACT A WITH (NOLOCK)
					,OCRD B WITH (NOLOCK)
					,OINV C WITH (NOLOCK)
				WHERE A.AcctCode = B.DebPayAcct
					AND LocManTran = 'Y'
					AND Fixed = 'Y'
					AND B.DebPayAcct IN (
						'15041000000'
						,'15041000001'
						,'15041000002'
						,'15041000003'
						,'15041000004'
						,'15041000005'
						,'15041000006'
						)
					AND B.CardCode = C.CardCode
					AND C.CardCode IS NOT NULL
					AND C.DocEntry = @DocEntry
				)
		BEGIN
			IF EXISTS (
					SELECT a.DocEntry,a.CardCode,a.NumAtCard,a.Series,a.u_ordtype,a.UserSign
					FROM [OINV] A WITH (NOLOCK)
					INNER JOIN [INV1] B WITH (NOLOCK) ON A.DocEntry = B.DocEntry
					LEFT JOIN OITM C WITH (NOLOCK) ON B.ItemCode=C.ItemCode
					LEFT JOIN OITB C1 WITH (NOLOCK) ON C.ItmsGrpCod=C1.ItmsGrpCod
					LEFT JOIN OCRD D WITH (NOLOCK) ON D.CardCode = A.CardCode
					LEFT JOIN NNM1 E With (NoLock) ON E.Series = A.Series
					WHERE (B.U_MRP IS NULL OR CONVERT(REAL, b.U_MRP) <= 0)
						AND B.U_CatalogName IS NOT NULL
						AND isnull(a.U_OrdType, '') NOT IN  ('AO')
						AND A.NumAtCard NOT IN ('RTN')
						AND A.DocEntry = @DocEntry
						AND C1.ItmsGrpNam NOT IN  ('WASTE')
						AND LEFT(E.SeriesName, 2) = 'SS'
						AND A.CardCode NOT IN ('C029075')
						AND A.UserSign IN (33,34,35,36,95,96,97,98,187,188,189,190,191,192,193)
						AND D.QryGroup1 NOT IN ('Y')
						AND c.QryGroup5 NOT IN ('Y'))
				SELECT @ErrorCode = 10
					,@ErrorName = 'MRP should not be left Empty'

			IF EXISTS (
					SELECT A.U_TotQty,A.DocNum
					FROM [OINV] A WITH (NOLOCK)
					WHERE (
							SELECT SUM(U_NoofPiece)
							FROM INV1 WITH (NOLOCK)
							WHERE DocEntry = A.DocEntry
							) <> A.U_TotQty
							AND A.DocEntry = @DocEntry )
				SELECT @ErrorCode = 10
					,@ErrorName = 'No.Of.Pcs Row Level Total & Header Level Total Should be Equal Please Check........'

			IF EXISTS (
					SELECT a.DocEntry,a.Series,a.U_OrdType,a.NumAtCard,a.UserSign
					FROM [OINV] A WITH (NOLOCK)
					INNER JOIN [INV1] B WITH (NOLOCK) ON A.DocEntry = B.DocEntry
					LEFT JOIN NNM1 C WITH (NOLOCK) ON A.Series = C.Series
					LEFT JOIN OITM D WITH (NOLOCK) ON B.ItemCode = D.ItemCode
					WHERE (B.U_SalPrice IS NULL OR CONVERT(REAL, b.u_salprice) <= 0 )
						AND B.U_CatalogName IS NOT NULL
						AND a.U_OrdType NOT IN ('AO')
						AND A.DocEntry = @DocEntry
						AND B.ItemCode NOT IN ('WHSEMB')
						AND Left(C.SeriesName, 2) = 'SS'
						AND D.ItmsGrpCod NOT IN ('138')
						AND A.NumAtCard NOT IN ('RTN')
						AND A.UserSign IN (33,34,35,36,95,96,97,98,187,188,189,190,191,192,193))
				SELECT @ErrorCode = 10,@ErrorName = 'Selling Price should not be left Empty'

			IF EXISTS (
					SELECT a.DocEntry,a.cardcode,a.Series,a.U_OrdType,a.NumAtCard,a.UserSign
					FROM [OINV] A WITH (NOLOCK)
					INNER JOIN [INV1] B WITH (NOLOCK) ON A.DocEntry = B.DocEntry
					LEFT JOIN OITM D WITH (NOLOCK) ON B.ItemCode = D.ItemCode
					LEFT JOIN NNM1 C WITH (NOLOCK) ON A.Series = C.Series
					WHERE b.PriceBefDi = 0
						AND A.DocEntry = @DocEntry
						AND Left(C.SeriesName, 2) = 'CS'
						AND D.ItmsGrpCod NOT IN (138)
						AND a.CardCode = 'C037724'
						AND A.UserSign IN (33,34,35,36,95,96,97,98,187,188,189,190,191,192,193)
						AND b.ItemCode NOT IN ('WHSEMB')
						AND A.NumAtCard NOT IN ('RTN'))
				SELECT @ErrorCode = 10,@ErrorName = 'Selling Price should not be left Empty'

			IF EXISTS (
					SELECT a.DocEntry
					FROM oinv a WITH (NOLOCK)
					INNER JOIN OCRD b WITH (NOLOCK) ON a.CardCode = b.CardCode
					WHERE A.DocEntry = @DocEntry
						AND b.U_MRPPricelist LIKE '%FR%'
					)
				SELECT @ErrorCode = 10
					,@ErrorName = 'Please Check the MRP... By mistake the FR is Selected in BP Master.'

			IF EXISTS (
					SELECT B.DiscPrcnt,DocNum
					FROM [OINV] A WITH (NOLOCK)
					INNER JOIN [INV1] B WITH (NOLOCK) ON A.DocEntry = B.DocEntry
					LEFT JOIN OCRD C WITH (NOLOCK) ON A.CardCode = C.CardCode
					WHERE (A.U_Dis1 + A.U_Dis2 + A.U_Dis3 + A.U_Dis4 + A.U_Dis5 + A.U_Dis6 + A.U_Dis7 + A.U_Dis8 + A.U_Dis1) <> 0.0
						AND B.DiscPrcnt = 0.0
						AND isnull(b.DiscPrcnt, 0) <100
						AND c.U_showcode NOT IN ('TP')
						AND A.DocEntry = @DocEntry
					)
				SELECT @ErrorCode = 11
					,@ErrorName = 'Please Check Row Level Discount Details is Missing.............'

			IF EXISTS (
					SELECT B.DocEntry,B.DiscPrcnt
					FROM [INV1] B WITH (NOLOCK)
					INNER JOIN OINV A WITH (NOLOCK) ON A.DocEntry = B.DocEntry
					WHERE isnull(b.DiscPrcnt, 0) < 0
						AND A.CANCELED = 'N'
						AND B.DocEntry = @DocEntry)
				SELECT @ErrorCode = 11
					,@ErrorName = 'Discount % Not Allowed Below Zero...'

			IF EXISTS (
					SELECT B.DiscPrcnt
						,DocNum
					FROM [OINV] A WITH (NOLOCK)
					INNER JOIN INV1 b WITH (NOLOCK) ON A.DocEntry = B.DocEntry
					LEFT JOIN [OCRD] C WITH (NOLOCK)  ON A.CardCode = C.CardCode
					WHERE ISNULL(C.U_Dis1, 0) <> B.DiscPrcnt
						AND c.U_showcode NOT IN ('TP')
						AND isnull(b.DiscPrcnt, 0) < 100 --and a.usersign<>3 
						AND B.ItemCode <> 'FrightCharges'
						AND A.DocEntry = @DocEntry
					)
				SELECT @ErrorCode = 11
					,@ErrorName = 'Please Check Row Level Discount is Miss Match...'

			IF EXISTS (
					SELECT a.DocEntry,a.Series,a.U_OrdType,a.NumAtCard,a.UserSign
					FROM [OINV] A WITH (NOLOCK)
					INNER JOIN [INV1] B WITH (NOLOCK) ON A.DocEntry = B.DocEntry
					LEFT JOIN NNM1 C WITH (NOLOCK) ON C.Series = A.Series
					WHERE B.PriceBefDi <> B.U_SalPrice
						AND B.U_CatalogName IS NOT NULL
						AND a.U_OrdType <> 'AO'
						AND A.UserSign IN (
							33
							,34
							,35
							,36
							,95
							,96
							,97
							,98
							,187
							,188
							,189
							,190
							,191
							,192
							,193
							)
						AND A.NumAtCard <> 'RTN'
						AND b.ItemCode <> 'WHSEMB'
						AND B.Dscription NOT LIKE '%WASTE%'
						AND Left(C.SeriesName, 2) = 'SS'
						AND A.DocEntry = @DocEntry
						AND a.UserSign NOT IN (96)
					)
				SELECT @ErrorCode = 11
					,@ErrorName = 'Selling Price && Unit Price should not be Equal'

			SET @ItemCode = (
					SELECT TOP 1 B.ItemCode
					FROM [OINV] A WITH (NOLOCK)
						,[INV1] B WITH (NOLOCK)
						,[INV12] K WITH (NOLOCK)
						,ITM1 E WITH (NOLOCK)
						,OCRD F WITH (NOLOCK)
						,OITM G WITH (NOLOCK)
						,NNM1 H WITH (NOLOCK)
					WHERE A.DocEntry = B.DocEntry
						AND k.docentry = b.DocEntry
						AND H.Series = A.Series
						AND LEFT(H.SeriesName, 2) = 'SS'
						AND F.CardCode = A.CardCode
						AND F.U_MRPListnum = E.PriceList
						AND E.Price <> b.U_MRP
						AND G.ItmsGrpCod NOT IN ('138')
						AND b.ItemCode <> 'WHSEMB'
						AND E.ItemCode = B.ItemCode
						AND G.ItemCode = B.ItemCode
						AND G.ItemName = B.U_CatalogName
						AND g.QryGroup5 <> 'Y'
						AND A.DocEntry = @DocEntry
						AND ISNULL(k.FormNo, '') = ''
						AND A.NumAtCard <> 'RTN'
						AND A.UserSign IN (
							33
							,34
							,35
							,36
							,95
							,96
							,97
							,98
							,187
							,188
							,189
							,190
							,191
							,192
							,193
							)
					)

			IF EXISTS (
					SELECT DISTINCT A.DocNum
						,B.U_SalPrice
						,E.Price
						,B.U_MRP
						,B.U_CatalogName
						,B.U_CatalogName
						,B.ItemCode
					FROM [OINV] A WITH (NOLOCK)
						,[INV1] B WITH (NOLOCK)
						,[INV12] K WITH (NOLOCK)
						,ITM1 E WITH (NOLOCK)
						,OCRD F WITH (NOLOCK)
						,OITM G WITH (NOLOCK)
						,NNM1 H WITH (NOLOCK)
					WHERE A.DocEntry = B.DocEntry
						AND k.docentry = b.DocEntry
						AND H.Series = A.Series
						AND LEFT(H.SeriesName, 2) = 'SS'
						AND F.CardCode = A.CardCode
						AND F.U_MRPListnum = E.PriceList
						AND E.Price <> b.U_MRP
						AND G.ItmsGrpCod NOT IN ('138')
						AND b.ItemCode <> 'WHSEMB'
						AND E.ItemCode = B.ItemCode
						AND G.ItemCode = B.ItemCode
						AND G.ItemName = B.U_CatalogName
						AND g.QryGroup5 <> 'Y'
						AND F.ListNum <> 35
						AND A.DocEntry = @DocEntry
						AND ISNULL(k.FormNo, '') = ''
						AND A.NumAtCard <> 'RTN'
						AND A.UserSign IN (
							33
							,34
							,35
							,36
							,95
							,96
							,97
							,98
							,187
							,188
							,189
							,190
							,191
							,192
							,193
							)
					)
				SELECT @ErrorCode = 11
					,@ErrorName = 'MRP Price && Price List Master price should not be Equal   ' + @ItemCode

			--TEST (11)
			IF EXISTS (
					SELECT DISTINCT A.DocNum
						,B.U_SalPrice
						,E.Price
						,B.U_MRP
						,B.U_CatalogName
						,B.U_CatalogName
						,B.ItemCode
					FROM [OINV] A WITH (NOLOCK)
						,[INV1] B WITH (NOLOCK)
						,[INV12] K WITH (NOLOCK)
						,ITM1 E WITH (NOLOCK)
						,OCRD F WITH (NOLOCK)
						,OITM G WITH (NOLOCK)
						,NNM1 H WITH (NOLOCK)
						,OUSR I WITH (NOLOCK)
					WHERE A.DocEntry = B.DocEntry
						AND k.docentry = b.DocEntry
						AND H.Series = A.Series
						AND LEFT(H.SeriesName, 2) = 'SS'
						AND A.UserSign = I.USERID
						AND F.CardCode = A.CardCode
						AND F.ListNum = E.PriceList
						AND E.Price <> b.PriceBefDi
						AND G.ItmsGrpCod <> '138'
						AND b.ItemCode <> 'WHSEMB'
						AND E.ItemCode = B.ItemCode
						AND G.ItemCode = B.ItemCode
						AND G.ItemName = B.U_CatalogName
						AND ItmsGrpCod NOT IN ('138')
						AND A.CardCode NOT IN (
							SELECT DISTINCT B.CardCode
							FROM OCRD A With (NoLock) 
							LEFT JOIN ORDR B With (NoLock)  ON A.CardCode = B.CardCode
							WHERE QryGroup18 = 'Y'
								AND B.U_Brand = 'VIVEAGA SHIRT'
							)
						AND A.DocEntry = @DocEntry
						AND ISNULL(k.FormNo, '') = ''
						AND B.Dscription NOT LIKE '%UNIFORM%'
						AND LEFT(I.USER_CODE, 6) IN (
							'RRDESP'
							,'SSDESP'
							)
					)
				SELECT @ErrorCode = 11
					,@ErrorName = 'Sale Price && Price List Master price should not be Equal'

			IF EXISTS (
					SELECT DISTINCT a.DocNum
						,a.DocDate
						,a.U_Lrwight
						,c.U_Lrwight
					FROM oinv a WITH (NOLOCK)
					INNER JOIN (
						SELECT DocEntry
							,BaseEntry
						FROM inv1 WITH (NOLOCK)
						) b ON a.DocEntry = b.DocEntry
					LEFT JOIN odln c WITH (NOLOCK) ON c.DocEntry = b.BaseEntry
					WHERE isnull(c.U_Lrwight, 0) > 0
						AND isnull(a.U_Lrwight, 0) = 0
						AND A.DocEntry = @DocEntry
					)
				SELECT @ErrorCode = 10
					,@ErrorName = 'Enter the Correct Weight of the Delivery...'

			IF EXISTS (
					SELECT a.DocNum
						,c.DocNum
						,a.DocDate
						,a.U_Lrwight
						,c.U_Lrwight
					FROM oinv a WITH (NOLOCK)
					INNER JOIN (
						SELECT DocEntry
							,BaseEntry
						FROM inv1 WITH (NOLOCK)
						) b ON a.DocEntry = b.DocEntry
					LEFT JOIN odln c WITH (NOLOCK) ON c.DocEntry = b.BaseEntry
					WHERE isnull(c.U_Lrwight, 0) > 0
						AND isnull(a.U_Lrwight, 0) > 0
						AND A.DocEntry = @DocEntry
					GROUP BY a.DocNum
						,c.DocNum
						,a.DocDate
						,a.U_Lrwight
						,c.U_Lrwight
					HAVING isnull(c.U_Lrwight, 0) <> isnull(a.U_Lrwight, 0)
					)
				SELECT @ErrorCode = 10
					,@ErrorName = 'Delivery Weight and Invoice Weight Mismatch...'
		END

		IF EXISTS (
				SELECT a.DocEntry,a.Series,a.U_OrdType,a.NumAtCard,a.UserSign,a.U_Brand
				FROM [OINV] A WITH (NOLOCK)
				INNER JOIN [INV1] B WITH (NOLOCK) ON A.DocEntry = B.DocEntry
				LEFT JOIN NNM1 C WITH (NOLOCK) ON C.Series = A.SERIES
				LEFT JOIN (
					SELECT ItemCode
						,ItmsGrpCod
					FROM OITM WITH (NOLOCK)
					) D ON D.ItemCode = B.ItemCode
				WHERE A.CardCode IS NOT NULL
					AND A.U_Brand IS NULL
					AND LEFT(C.SeriesName, 2) = 'SS'
					AND D.ItmsGrpCod NOT IN (
						105
						,138
						)
					AND a.U_OrdType <> 'AO'
					AND a.DocType <> 'S'
					AND A.CardCode <> 'C037724'
					AND B.Dscription NOT LIKE '%WASTE%'
					AND A.DocEntry = @DocEntry
				)
			SELECT @ErrorCode = 10
				,@ErrorName = 'Brand should not be left Empty'

		IF EXISTS (
				SELECT a.DocEntry,a.Series,a.U_OrdType,a.NumAtCard,a.UserSign,a.u_brand
				FROM [OINV] A WITH (NOLOCK)
				INNER JOIN [INV1] B WITH (NOLOCK) ON A.DocEntry = B.DocEntry
				LEFT JOIN NNM1 C WITH (NOLOCK) ON C.Series = A.SERIES
				WHERE A.CardCode IS NOT NULL
					AND A.U_Arcode IS NULL
					AND a.U_OrdType <> 'AO'
					AND ISNULL(A.U_Brand, '') <> ''
					AND LEFT(C.SeriesName, 2) = 'SS'
					AND A.CardCode <> 'C037724'
					AND a.DocType <> 'S'
					AND A.DocEntry = @DocEntry
				)
			SELECT @ErrorCode = 10
				,@ErrorName = 'AreaCode should not be left Empty'

		--     If Exists(        
		--Select  *  From   [OINV]   A Inner Join [INV1] B  ON A.DocEntry=B.DocEntry         
		--Where A.CardCode  is not null And A.U_Transport  is null  and a.U_Type<>'C' AND A.CardCode<>'C037724' and a.DocType<>'S'  And A.DocEntry=@DocEntry)             
		--SELECT  @ErrorCode=10 , @ErrorName = 'Transport should not be left Empty'  
		IF EXISTS (
				SELECT a.DocEntry,a.Series,a.U_OrdType,a.NumAtCard,a.UserSign,a.U_Transport
				FROM OINV A WITH (NOLOCK)
					,OCRD b WITH (NOLOCK)
					,NNM1 C WITH (NOLOCK)
					,INV6 d With (NoLock) 
				WHERE A.CardCode = b.CardCode
					AND a.DocEntry = @DocEntry
					AND a.DocEntry = d.DocEntry
					AND A.Series = C.Series
					AND LEFT(C.SeriesName, 2) = 'SS'
					AND a.DocType <> 'S'
					AND A.U_Transport NOT LIKE '%PAID%'
					AND b.u_showcode <> 'DR'
					AND A.U_Pass = 'PAID'
					AND d.TotalExpns = 0
				)
			SELECT @ErrorCode = 10
				,@ErrorName = 'Please Select Transport Paid and Add Paid Charges....'

		IF EXISTS (
				SELECT a.DocEntry,a.Series,a.U_OrdType,a.NumAtCard,a.UserSign,a.U_Transport
				FROM OINV A WITH (NOLOCK)
					,OCRD b WITH (NOLOCK)
					,NNM1 C WITH (NOLOCK)
					,INV6 d With (NoLock) 
				WHERE A.CardCode = b.CardCode
					AND a.DocEntry = @DocEntry
					AND a.DocEntry = d.DocEntry
					AND A.Series = C.Series
					AND LEFT(C.SeriesName, 2) = 'SS'
					AND b.u_showcode <> 'DR'
					AND a.DocType <> 'S' --and a.UserSign<>'3'
					AND A.U_Transport LIKE '%PAID%'
					AND A.U_Pass <> 'PAID'
					AND d.TotalExpns >= 0
				)
			SELECT @ErrorCode = 10
				,@ErrorName = 'Please Select To.Pay Field and Add Paid Charges....'

		IF EXISTS (
				SELECT a.DocEntry,a.Series,a.U_OrdType,a.NumAtCard,a.UserSign,a.u_pass,a.U_Transport
				FROM [OINV] A WITH (NOLOCK)
					,[NNM1] B WITH (NOLOCK)
				WHERE A.Series = B.Series
					AND A.U_Transport LIKE '%TBB%'
					AND A.U_Pass <> 'TBB'
					AND LEFT(B.SeriesName, 2) = 'SS'
					AND A.DocEntry = @DocEntry
				)
			SELECT @ErrorCode = 10
				,@ErrorName = 'Select TBB (Work Carefully ...)'

		IF EXISTS (
				SELECT a.DocEntry,a.Series,a.U_OrdType,a.NumAtCard,a.UserSign,a.u_pass,a.U_Transport,a.U_Transit
				FROM [OINV] A WITH (NOLOCK)
					,[NNM1] B WITH (NOLOCK)
				WHERE A.Series = B.Series
					AND A.U_Transport LIKE '%WITH PASS%'
					AND ISNULL(A.U_Transit,'') IN ('DD','OD','')
					AND LEFT(B.SeriesName, 2) = 'SS'
					AND A.DocEntry = @DocEntry
				)
			SELECT @ErrorCode = 10
				,@ErrorName = 'Please Select Correct Transit Mode (With Pass)'
				
		IF EXISTS (
				SELECT a.DocEntry,a.Series,a.U_OrdType,a.NumAtCard,a.UserSign,a.u_pass,a.U_Transport,a.U_Transit
				FROM [OINV] A WITH (NOLOCK)
					,[NNM1] B WITH (NOLOCK)
				WHERE A.Series = B.Series
					AND A.U_Transport LIKE '%OFFICE%'
					AND ISNULL(A.U_Transit,'') IN ('DD','WP','')
					AND LEFT(B.SeriesName, 2) = 'SS'
					AND A.DocEntry = @DocEntry
				)
			SELECT @ErrorCode = 10
				,@ErrorName = 'Please Select Correct Transit Mode (Office Delivery)'		
				
		IF EXISTS (
				SELECT a.DocEntry,a.Series,a.U_OrdType,a.NumAtCard,a.UserSign,a.u_pass,a.U_Transport,a.U_Transit
				FROM [OINV] A WITH (NOLOCK)
					,[NNM1] B WITH (NOLOCK)
				WHERE A.Series = B.Series
					AND ISNULL(A.U_Transit,'') IN ('')
					AND LEFT(B.SeriesName, 2) = 'SS'
					AND A.DocEntry = @DocEntry
				)
			SELECT @ErrorCode = 10
				,@ErrorName = 'Please Select Correct Transit Mode...'		
				
		IF EXISTS (
				SELECT a.DocEntry,a.Series,a.U_Type,a.CardCode, A.U_OrdType,a.NumAtCard,a.UserSign,a.u_pass,a.U_Transport,a.U_Transit
				FROM [OINV] A WITH (NOLOCK)
				INNER JOIN [INV1] B WITH (NOLOCK) ON A.DocEntry = B.DocEntry
				WHERE A.CardCode IS NOT NULL
					AND A.U_Dsnation IS NULL
					AND a.U_Type <> 'C'
					AND A.CardCode <> 'C037724'
					AND A.DocEntry = @DocEntry
				)
			SELECT @ErrorCode = 10
				,@ErrorName = 'Destination should not be left Empty'

		IF EXISTS (
				SELECT a.DocEntry,a.Series,a.U_Type,a.CardCode, A.U_OrdType,a.NumAtCard,a.UserSign,a.u_pass,a.U_Transport,a.U_Transit
				FROM [OINV] A WITH (NOLOCK)
				INNER JOIN [INV1] B WITH (NOLOCK) ON A.DocEntry = B.DocEntry
				WHERE A.CardCode IS NOT NULL
					AND A.NumAtCard IS NULL
					AND a.U_Type <> 'C'
					AND A.CardCode <> 'C037724'
					AND A.DocEntry = @DocEntry
				)
			SELECT @ErrorCode = 10
				,@ErrorName = 'Customer Ref No should not be left Empty'

		IF EXISTS (
				SELECT b.DocEntry,b.Series,b.U_Type,b.CardCode, b.U_OrdType,b.NumAtCard,b.UserSign,b.u_pass,b.U_Transport,b.U_Transit
				FROM CRD1 A WITH (NOLOCK)
					,[OINV] B WITH (NOLOCK)
				WHERE A.CardCode = B.CardCode
					AND City IS NULL
					AND B.CardCode IS NOT NULL
					AND B.DocEntry = @DocEntry
				)
			SELECT @ErrorCode = 10
				,@ErrorName = 'Please Check BP Master Customer CityName is Missing....'

		IF EXISTS (
				SELECT  b.DocEntry,b.Series,b.U_Type,b.CardCode, b.U_OrdType,b.NumAtCard,b.UserSign,b.u_pass,b.U_Transport,b.U_Transit
				FROM CRD1 A WITH (NOLOCK)
					,[OINV] B WITH (NOLOCK)
				WHERE A.CardCode = B.CardCode
					AND STATE IS NULL
					AND B.CardCode IS NOT NULL
					AND B.DocEntry = @DocEntry
				)
			SELECT @ErrorCode = 10
				,@ErrorName = 'Please Check BP Master Customer State is Missing....'

		IF EXISTS (
				SELECT count(DISTINCT t1.CardCode)
				FROM oinv t1 WITH (NOLOCK)
				WHERE CASE 
						WHEN CONVERT(NVARCHAR(MAX), ISNULL(U_REFNO, '')) = ''
							THEN CONVERT(NVARCHAR(MAX), ISNULL(DOCNUM, ''))
						ELSE CONVERT(NVARCHAR(MAX), ISNULL(U_REFNO, ''))
						END = (
						SELECT CASE 
								WHEN CONVERT(NVARCHAR(MAX), ISNULL(U_REFNO, '')) = ''
									THEN CONVERT(NVARCHAR(MAX), ISNULL(DOCNUM, ''))
								ELSE CONVERT(NVARCHAR(MAX), ISNULL(U_REFNO, ''))
								END
						FROM OINV With (NoLock) 
						WHERE DocEntry = @DocEntry
							AND PIndicator = (
								SELECT DISTINCT indicator
								FROM ofpr With (NoLock) 
								WHERE convert(DATE, getdate()) BETWEEN F_RefDate
										AND T_RefDate
								)
						)
					AND pindicator = (
						SELECT DISTINCT indicator
						FROM ofpr With (NoLock) 
						WHERE convert(DATE, getdate()) BETWEEN F_RefDate
								AND T_RefDate
						)
				HAVING count(DISTINCT CardCode) > 1
				)
			SELECT @ErrorCode = 10
				,@ErrorName = 'Joint Order Not Allowed, Because Party Name Not Matched...'

		IF EXISTS (
				SELECT DISTINCT a.DocEntry
					,a.DocNum
					,a.DocDate
					,a.CardCode
					,a.CardName
					,a.U_Type
					,AcctCode
				FROM oinv a With (NoLock) 
				LEFT JOIN inv1 b With (NoLock)  ON a.DocEntry = b.DocEntry
				LEFT JOIN ousr us With (NoLock)  ON us.USERID = a.UserSign
				WHERE b.AcctCode IN (
						'40002050000'
						,'40002080000'
						,'40002120000'
						)
					AND a.DocEntry = @DocEntry
					AND a.U_Type <> 'J'
					AND left(us.U_NAME, 6) IN (
						'rrdesp'
						,'ssdesp'
						)
				)
			SELECT @ErrorCode = 10
				,@ErrorName = 'Please Select Type of Job Work... '
	END

	------------- Regular Invoice Validations   
	IF EXISTS (
			SELECT a.DocEntry,a.whscode
			FROM INV1 a WITH (NOLOCK)
				,OWHS b WITH (NOLOCK)
			WHERE a.WhsCode = b.WhsCode
				AND b.DropShip = 'Y'
				AND a.DocEntry = @DocEntry
			)
	BEGIN
		IF EXISTS (
				SELECT *
				FROM [OINV] A WITH (NOLOCK)
				INNER JOIN [INV1] B WITH (NOLOCK) ON A.DocEntry = B.DocEntry
				LEFT JOIN (
					SELECT ItemCode
						,ItmsGrpCod
					FROM oitm WITH (NOLOCK)
					) c ON c.ItemCode = b.ItemCode
				WHERE B.U_Size IS NULL
					AND isnull(B.U_CatalogName, '') <> isnull(b.U_CatalogCode, '')
					AND a.U_Type <> 'C'
					AND c.ItmsGrpCod NOT IN (138)
					AND A.DocEntry = @DocEntry
				)
			SELECT @ErrorCode = 10
				,@ErrorName = 'CatalogName or CatalogCode Not Match'

		IF EXISTS (
				SELECT *
				FROM [OINV] A WITH (NOLOCK)
				INNER JOIN [INV1] B WITH (NOLOCK) ON A.DocEntry = B.DocEntry
				LEFT JOIN (
					SELECT ItemCode
						,ItmsGrpCod
					FROM oitm WITH (NOLOCK)
					) c ON c.ItemCode = b.ItemCode
				WHERE A.CardCode IS NOT NULL
					AND A.U_Brand IS NULL
					AND a.U_OrdType <> 'AO'
					AND c.ItmsGrpCod NOT IN (138)
					AND a.U_Type <> 'C'
					AND A.DocEntry = @DocEntry
				)
			SELECT @ErrorCode = 10
				,@ErrorName = 'Brand should not be left Empty'

		IF EXISTS (
				SELECT *
				FROM [OINV] A WITH (NOLOCK)
				INNER JOIN [INV1] B WITH (NOLOCK) ON A.DocEntry = B.DocEntry
				WHERE A.CardCode IS NOT NULL
					AND A.U_Arcode IS NULL
					AND a.U_OrdType <> 'AO'
					AND a.U_Type <> 'C'
					AND A.DocEntry = @DocEntry
				)
			SELECT @ErrorCode = 10
				,@ErrorName = 'AreaCode should not be left Empty'

		IF EXISTS (
				SELECT *
				FROM [OINV] A WITH (NOLOCK)
				INNER JOIN [INV1] B WITH (NOLOCK) ON A.DocEntry = B.DocEntry
				WHERE A.CardCode IS NOT NULL
					AND A.U_Transport IS NULL
					AND a.U_Type <> 'C'
					AND A.DocEntry = @DocEntry
				)
			SELECT @ErrorCode = 10
				,@ErrorName = 'Transport should not be left Empty'

		-- If Exists(        
		--Select  *  From   [OINV]   A Inner Join [INV1] B  ON A.DocEntry=B.DocEntry         
		--Where A.CardCode  is not null And A.U_Dsnation  is null  and a.U_Type<>'C'   And A.DocEntry=@DocEntry)             
		--SELECT  @ErrorCode=10 , @ErrorName = 'Destination should not be left Empty'   
		IF EXISTS (
				SELECT a.DocEntry,a.U_Type,a.CardCode,a.numatcard
				FROM [OINV] A WITH (NOLOCK)
				INNER JOIN [INV1] B WITH (NOLOCK) ON A.DocEntry = B.DocEntry
				WHERE A.CardCode IS NOT NULL
					AND A.NumAtCard IS NULL
					AND a.U_Type <> 'C'
					AND A.DocEntry = @DocEntry
				)
			SELECT @ErrorCode = 10
				,@ErrorName = 'Customer Ref No should not be left Empty'

		IF EXISTS (
				SELECT b.DocEntry,b.CardCode
				FROM CRD1 A WITH (NOLOCK)
					,[OINV] B WITH (NOLOCK)
				WHERE A.CardCode = B.CardCode
					AND City IS NULL
					AND B.CardCode IS NOT NULL
					AND B.DocEntry = @DocEntry
				)
			SELECT @ErrorCode = 10
				,@ErrorName = 'Please Check BP Master Customer CityName is Missing..............'

		IF EXISTS (
				SELECT  b.DocEntry,b.CardCode
				FROM CRD1 A WITH (NOLOCK)
					,[OINV] B WITH (NOLOCK)
				WHERE A.CardCode = B.CardCode
					AND STATE IS NULL
					AND B.CardCode IS NOT NULL
					AND B.DocEntry = @DocEntry
				)
			SELECT @ErrorCode = 10
				,@ErrorName = 'Please Check BP Master Customer State is Missing..................'

		IF EXISTS (
				SELECT  a.DocEntry,a.CardCode,a.Series,a.usersign
				FROM [OINV] a WITH (NOLOCK)
					,nnm1 b WITH (NOLOCK)
				WHERE a.series = b.series
					AND LEFT(b.seriesname, 2) NOT IN ('PR')
					AND usersign IN (
						4
						,5
						,6
						,30
						,32
						,112
						)
					AND a.DocEntry = @DocEntry
				)
			SELECT @ErrorCode = 10
				,@ErrorName = 'Check Docnument Numbering Series '
	END

	IF EXISTS (
			SELECT a.DocEntry
			FROM INV12 a WITH (NOLOCK)
			WHERE a.DocEntry = @DocEntry
				AND ISNULL(STATE, '') = ''
			)
		SELECT @ErrorCode = 38
			,@ErrorName = 'STATE should not be left Empty'

	IF EXISTS (
			SELECT a.DocEntry,a.CardCode,a.Series,a.usersign,a.U_Brand,a.U_Distance
			FROM OINV a WITH (NOLOCK)
				,NNM1 B WITH (NOLOCK)
			WHERE a.DocEntry = @DocEntry
				AND ISNULL(U_Distance, '') = ''
				AND B.Series = A.Series
				AND LEFT(B.SeriesName, 2) = 'SS'
				AND ISNULL(A.U_Brand, '') <> ''
			)
		SELECT @ErrorCode = 38
			,@ErrorName = 'Distance should not be left Empty'

	IF EXISTS (
			SELECT a.U_Distance
				,a.DocNum
				,a.CardCode
				,a.CardName
				,a.U_Distance INVDist
				,isnull(b.U_Distance, 0) BPDist
				,isnull(b.U_Distance, 0) + isnull(b.U_Distance, 0) * 10 / 100 CalDist
			FROM oinv a WITH (NOLOCK)
			LEFT JOIN ocrd b WITH (NOLOCK) ON a.CardCode = b.CardCode
			LEFT JOIN nnm1 c WITH (NOLOCK) ON c.Series = a.Series
			WHERE (isnull(b.U_Distance, 0) + isnull(b.U_Distance, 0) * 10 / 100) < isnull(a.U_Distance, 0)
				AND a.DocEntry = @DocEntry
				AND left(c.SeriesName, 2) = 'SS'
				AND a.UserSign <> 199
			)
		SELECT @ErrorCode = 38
			,@ErrorName = 'BP Master Distance and Invoice Distance is Below.'

	IF EXISTS (
			SELECT a.DocEntry,a.CardCode,a.Series,a.usersign,a.U_Brand,a.U_RefNo,a.comments
			FROM OINV A WITH (NOLOCK)
				,NNM1 C WITH (NOLOCK)
			WHERE a.DocEntry = @DocEntry
				AND A.Series = C.Series
				AND LEFT(C.SeriesName, 2) = 'SS'
				AND A.Comments LIKE '%ALONG%'
				AND ISNULL(A.U_RefNo, '') = ''
			)
		SELECT @ErrorCode = 38
			,@ErrorName = 'Please Enter the Ref. No (This is a Joint order)'

	IF EXISTS (
			SELECT a.DocEntry,a.CardCode,a.Series,a.usersign,a.U_Brand,a.U_RefNo,a.comments
			FROM OINV A WITH (NOLOCK)
				,NNM1 C WITH (NOLOCK)
			WHERE a.DocEntry = @DocEntry
				AND A.Series = C.Series
				AND LEFT(C.SeriesName, 2) = 'SS'
				AND LEN(ISNULL(A.U_RefNo, 0)) > 6
			)
		SELECT @ErrorCode = 38
			,@ErrorName = 'Ref.No Above Six Characters Please Check...'

	IF EXISTS (
			SELECT a.DocEntry,a.CardCode,a.Series,a.usersign,a.U_Brand,a.U_RefNo,a.comments
			FROM OINV A WITH (NOLOCK)
				,NNM1 C WITH (NOLOCK)
			WHERE a.DocEntry = @DocEntry
				AND A.Series = C.Series
				AND LEFT(C.SeriesName, 2) = 'SS'
				AND A.Comments LIKE '%ALONG%'
				AND ISNULL(A.U_RefNo, '') = ''
			)
		SELECT @ErrorCode = 38
			,@ErrorName = 'Please Enter the Ref. No (This is a Joint order)'

	IF EXISTS (
			SELECT a.DocEntry,a.CardCode,a.Series,a.usersign,a.U_Brand,a.U_RefNo,a.comments,a.CANCELED,a.doctype
			FROM OINV A WITH (NOLOCK)
			LEFT JOIN (
				SELECT Series
					,SeriesName
				FROM NNM1 WITH (NOLOCK)
				) c ON A.Series = C.Series
			WHERE a.DocEntry = @DocEntry
				AND LEFT(C.SeriesName, 2) = 'SS'
				AND A.CANCELED = 'N' --And a.UserSign Not in (3)
				AND a.Comments LIKE '%Invoice%'
				AND isnull(a.U_courpodno, '') = ''
				AND a.DocType <> 'S'
			)
		SELECT @ErrorCode = 38
			,@ErrorName = 'Please Update to Courier POD No. "WB"'

	IF EXISTS (
			SELECT a.DocEntry,a.CardCode,a.Series,a.usersign,a.U_Brand,a.U_RefNo,
			a.comments,a.CANCELED,a.doctype,a.U_Transport,a.u_courpodno
			FROM OINV A WITH (NOLOCK)
			LEFT JOIN (
				SELECT Series
					,SeriesName
				FROM NNM1 WITH (NOLOCK)
				) c ON A.Series = C.Series
			WHERE a.DocEntry = @DocEntry
				AND LEFT(C.SeriesName, 2) = 'SS'
				AND U_Transport LIKE '%PRF%'
				AND isnull(a.U_courpodno, '') = ''
			)
		SELECT @ErrorCode = 38
			,@ErrorName = 'Please Update to Courier POD No. "WB"'

	IF EXISTS (
			SELECT a.DocEntry,a.CardCode,a.Series,a.usersign,a.U_Brand,a.U_RefNo,
			a.comments,a.CANCELED,a.doctype,a.U_Transport,a.u_courpodno,a.U_TransporterId,a.u_vehno
			FROM OINV A WITH (NOLOCK)
				,OCRD B WITH (NOLOCK)
			WHERE a.DocEntry = @DocEntry
				AND a.U_TransporterName = b.CardFName
				AND b.U_showcode = 'TP'
				AND a.UserSign2 <> '98'
				AND isnull(a.U_TransporterId, '') <> isnull(b.U_TransporterId, B.U_GSTIN)
				AND isnull(a.U_VehNo, '') = ''
			)
		SELECT @ErrorCode = 38
			,@ErrorName = 'Select the Correct Transporter ID or NAME'

	IF EXISTS (
			SELECT a.DocNum
				,a.DocEntry
				,a.U_TransporterName
			FROM oinv a WITH (NOLOCK)
			LEFT JOIN nnm1 c WITH (NOLOCK) ON a.Series = c.Series
			WHERE a.DocEntry = @DocEntry
				AND isnull(a.U_TransporterName, '') NOT IN (
					SELECT isnull(U_TransporterName, '')
					FROM ocrd
					WHERE U_showcode = 'TP'
					) --and b.validFor='Y'
				AND left(c.SeriesName, 2) = 'SS'
				AND isnull(a.U_VehNo, '') = ''
			)
		SELECT @ErrorCode = 37
			,@ErrorName = 'Kindly Check Transporter Name... (Transporter Name is Wrong or InActivated)'

	/*If Exists ( select a.DocEntry,a.DocNum,a.DocDate,a.CardCode,a.CardName,a.U_Noofbun,max(b.PackageNum)Bale from oinv a   
 left join rinv8 b on a.DocEntry=b.DocEntry  
 where a.DocEntry=@DocEntry and isnull(a.U_RefNo,'')='' and a.DocType<>'S'  
 group by a.DocEntry,a.DocNum,a.DocDate,a.CardCode,a.CardName,a.U_Noofbun  
 having U_Noofbun<>max(b.PackageNum))  
SELECT @ErrorCode = 38 ,@ErrorName = 'Package Bundle(s) and Invoiced No.of Bundle(s) Not Matched...'  */
	IF EXISTS (
			SELECT a.DocEntry,a.CardCode,a.Series,a.usersign,a.U_Brand,a.U_RefNo,
			a.comments,a.CANCELED,a.doctype,a.U_Transport,a.u_courpodno,a.U_Noofbun
			FROM OINV A WITH (NOLOCK)
				,NNM1 C WITH (NOLOCK)
			WHERE a.DocEntry = @DocEntry
				AND A.Series = C.Series
				AND LEFT(C.SeriesName, 2) = 'SS'
				AND a.DocType <> 'S'
				AND a.CardCode NOT IN ('C037724')
				AND convert(INT, isnull(a.U_Noofbun, 0)) <= '0'
			)
		SELECT @ErrorCode = 38
			,@ErrorName = 'Please Select No.of Bundle(s))'

	IF EXISTS (
			SELECT docentry,u_gstin
			FROM OINV With (NoLock) 
			WHERE ISNULL(U_GSTIN, '') <> 'UNREGISTERED'
				AND CardCode = @DocEntry
			)
	BEGIN
		IF EXISTS (
				SELECT a.DocEntry,a.U_GSTIN
				FROM OINV A WITH (NOLOCK)
					,INV12 C WITH (NOLOCK)
					,OCST B WITH (NOLOCK)
				WHERE A.DocEntry = C.DocEntry
					AND C.StateB = ISNULL(B.Code, '')
					AND B.Country = 'IN'
					AND LEFT(ISNULL(a.u_gstin, ''), 2) <> ISNULL(b.eCode, '')
					AND isnull(a.U_GSTIN, '') <> ''
					AND A.DocEntry = @DocEntry
				)
			SELECT @ErrorCode = 11
				,@ErrorName = 'GSTIN OR BILL STATE WRONG or GST No is Empty'
	END

	IF EXISTS (
			SELECT a.DocEntry,a.U_Type,a.u_vehno
			FROM OINV a WITH (NOLOCK)
			WHERE /*A.DocTotal > 50000 AND*/ a.U_Type <> 'C'
				AND a.DocEntry = @DocEntry
				AND a.U_Type <> 'C'
				AND ISNULL(U_VehNo, '') = ''
			)
	BEGIN
		IF EXISTS (
				SELECT a.DocNum
				FROM OINV a WITH (NOLOCK)
				WHERE /*A.DocTotal > 50000 AND*/ a.U_Type <> 'C'
					AND a.DocEntry = @DocEntry
					AND a.U_Type <> 'C'
					AND ISNULL(U_TransporterId, '') = ''
				)
			SELECT @ErrorCode = 37
				,@ErrorName = 'TransportedId Should Not Be Left Empty'
	END

	IF EXISTS (
			SELECT a.DocNum
			FROM OINV a WITH (NOLOCK)
			WHERE /*A.DocTotal > 50000 AND*/ a.U_Type <> 'C'
				AND a.DocEntry = @DocEntry
				AND a.U_Type <> 'C'
				AND ISNULL(U_TransporterId, '') = ''
			)
	BEGIN
		IF EXISTS (
				SELECT a.DocNum
				FROM OINV a
				WHERE /*A.DocTotal > 50000 AND*/ a.U_Type <> 'C'
					AND a.DocEntry = @DocEntry
					AND a.U_Type <> 'C'
					AND LEFT(U_VehNo, 2) NOT IN (
						SELECT Code
						FROM OCST With (NoLock) 
						)
					AND a.UserSign2 <> '98'
				)
			SELECT @ErrorCode = 37
				,@ErrorName = 'Vechile Should Not Be Left Empty'

		IF EXISTS (
				SELECT *
				FROM OINV A WITH (NOLOCK)
					,INV1 b WITH (NOLOCK)
				WHERE A.DocEntry = b.DocEntry
					AND a.DocEntry = @DocEntry
					AND left(a.U_GSTIN, 2) <> '33'
					AND b.TaxCode LIKE '%CSGST%'
					AND A.U_GSTIN NOT IN ('UNREGISTERED')
				)
			SELECT @ErrorCode = 39
				,@ErrorName = 'Taxcode Or State Wrong Kindly Check'

		IF EXISTS (
				SELECT a.docentry,a.u_gstin
				FROM OINV A WITH (NOLOCK)
					,INV1 b WITH (NOLOCK)
				WHERE A.DocEntry = b.DocEntry
					AND a.DocEntry = @DocEntry
					AND left(a.U_GSTIN, 2) = '33'
					AND b.TaxCode LIKE '%IGST%'
					AND A.U_GSTIN NOT IN ('UNREGISTERED')
				)
			SELECT @ErrorCode = 40
				,@ErrorName = 'Taxcode Or State Wrong Kindly Check'

		--IF EXISTS (
		--		SELECT a.DocEntry,a.CardCode,a.Series,a.u_pass
		--		FROM OINV A WITH (NOLOCK)
		--			,OCRD b WITH (NOLOCK)
		--			,NNM1 C WITH (NOLOCK)
		--		WHERE A.CardCode = b.CardCode
		--			AND a.DocEntry = @DocEntry
		--			AND A.Series = C.Series
		--			AND LEFT(C.SeriesName, 2) = 'SS'
		--			AND b.QryGroup13 = 'Y'
		--			AND A.U_Pass <> 'PAID'
		--		)
		--	SELECT @ErrorCode = 10
		--		,@ErrorName = 'Please Add Paid Charges or Select Paid'

		IF EXISTS (
				SELECT a.DocEntry,a.cardcode,a.series,a.u_transport,a.u_pass
				FROM OINV A WITH (NOLOCK)
					,NNM1 C WITH (NOLOCK)
				WHERE a.DocEntry = @DocEntry
					AND A.Series = C.Series
					AND LEFT(C.SeriesName, 2) = 'SS'
					AND A.U_Transport LIKE '%PAID%'
					AND A.U_Pass <> 'PAID'
				)
			SELECT @ErrorCode = 10
				,@ErrorName = 'Please Add Paid Charges or Select Paid'

		---------------------------------------errors by gowtham----------------------
		IF NOT EXISTS (
				SELECT DISTINCT SalUnitMsr
				FROM oinv a WITH (NOLOCK)
				INNER JOIN inv1 b WITH (NOLOCK) ON a.docentry = b.docentry
				INNER JOIN oitm c WITH (NOLOCK) ON b.ItemCode = c.ItemCode
					AND b.TreeType <> 'i'
					AND DocType <> 'S'
				WHERE A.docentry = @DOCENTRY
					AND len(SalUnitMsr) >= 3
				)
			SELECT @ErrorCode = 50
				,@ErrorName = 'UOM Length should be equal to or greater than 3 digits'

		IF EXISTS (
				SELECT ISNULL(SalUnitMsr, 0)
				FROM oinv a WITH (NOLOCK)
				INNER JOIN inv1 b WITH (NOLOCK) ON a.docentry = b.docentry
				INNER JOIN oitm c WITH (NOLOCK) ON b.ItemCode = c.ItemCode
					AND b.TreeType <> 'i'
					AND DocType <> 'S'
				WHERE A.docentry = @DOCENTRY
					AND ISNULL(SalUnitMsr, 0) = '0'
				)
			SELECT @ErrorCode = 50
				,@ErrorName = 'UOM should not be empty'

		---------------------------------------------------------------------------------------------------------------------------
		IF NOT EXISTS (
				SELECT A.U_HSNCODE
					,B.U_HSNCODE
				FROM INV1 A WITH (NOLOCK)
				INNER JOIN OITM B WITH (NOLOCK) ON A.ItemCode = B.ItemCode
				WHERE ISNULL(A.U_HSNCODE, B.U_HSNCODE) >= 4
				)
			SELECT @ErrorCode = 50
				,@ErrorName = ('004 Check the HSN CODE --- OITM & INV1 ');

		-------------------------------------------------------------------------------------------------------------------------------
		-- IF EXISTS 
		-- (SELECT B.U_GSTIN FROM  OCRD A   
		--INNER JOIN OINV B ON A.CARDCODE=B.CARDCODE 
		--INNER JOIN (SELECT CASE WHEN LEN(ECODE)<2 THEN ('0'+CONVERT(NVARCHAR(2),ECODE)) ELSE CONVERT(NVARCHAR(2),ECODE) END E_CODE FROM OCST) C ON B.U_State=C.E_CODE
		-- WHERE isnull(Convert(varchar(2),A.[U_VStateCode]),Convert(varchar(2),c.E_CODE))<> LEFT(B.U_GSTIN,2)
		--  AND U_VStateCode IS NOT NULL AND B.U_GSTIN NOT LIKE '%UNREGIS%' AND B.DOCENTRY=@DocEntry)
		-- SELECT @ErrorCode=50,@ErrorName =('005 Statecode and GSTin Not Matched ');
		--------------------------------------------------------------------------------------------------------------------------------- 
		--DECLARE @E_MAIL AS NVARCHAR(14)
		--SELECT @E_MAIL=E_MAIL FROM OCRD a with (nolock) inner join oinv b with (nolock) on a.cardcode=b.CardCode  WHERE B.DOCENTRY=@DocEntry
		--IF ISNULL(@E_MAIL,'')<>''
		--BEGIN
		--IF EXISTS (select Phone1 from ocrd a with (nolock) inner join oinv b with (nolock) on a.cardcode=b.CardCode 
		--where len(E_MAIL)<4 and b.docentry=@DocEntry)
		-- SELECT @ErrorCode=50,@ErrorName =('008 Valid E-Mail Required (Length>6) ');
		--END
		-----------------------------------------------------------------------------------------------------------------------
		--DECLARE @PHONE1 AS NVARCHAR(14)
		--SELECT @PHONE1=PHONE1 FROM OCRD a with (nolock) inner join oinv b with (nolock) on a.cardcode=b.CardCode  WHERE B.DOCENTRY=@DocEntry
		--IF ISNULL(@PHONE1,'')<>''
		--BEGIN
		--IF EXISTS (select Phone1 from ocrd a inner join oinv b on a.cardcode=b.CardCode 
		--where len(PHONE1)<4 and b.docentry=@DocEntry)
		-- SELECT @ErrorCode=50,@ErrorName =('009 Valid Phone No. Required (Length>6) ');
		--END
		-----------------------------------------------------------------------------------------------------------------------------------
		IF EXISTS (
				SELECT U_VGstStatus
				FROM ocrd a WITH (NOLOCK)
				INNER JOIN oinv b WITH (NOLOCK) ON a.cardcode = b.CardCode
				WHERE U_VGstStatus IN (
						'CNL'
						,'INA'
						,'PRO'
						)
					AND B.DOCENTRY = @DOCENTRY
				)
			SELECT @ErrorCode = 50
				,@ErrorName = ('010 GST Should be active {Check GST Status}');

		-------------------------------------------------------------------------------------------------------------------------------------
		IF EXISTS (
				SELECT cardfname
				FROM ocrd a WITH (NOLOCK)
				INNER JOIN oinv b WITH (NOLOCK) ON a.cardcode = b.cardcode
				WHERE isnull(CardFName, '') = ''
					AND B.DOCENTRY = @DOCENTRY
				)
			SELECT @ErrorCode = 50
				,@ErrorName = ('011 CardFname should not be empty{}');

		-------------------------------------------------------------------------------------------------------------------------------------
		IF EXISTS (
				SELECT U_SACCODE
				FROM OINV A WITH (NOLOCK)
				INNER JOIN INV1 B WITH (NOLOCK) ON A.DOCENTRY = B.DOCENTRY
				WHERE U_SACCODE LIKE '99%'
					AND doctype <> 's'
					AND a.docentry = @DocEntry
				)
			SELECT @ErrorCode = 50
				,@ErrorName = ('013 Check HSN Code & SAC Code')
	END

	IF EXISTS (
			SELECT *
			FROM OINV WITH (NOLOCK)
			WHERE isnull(U_CanRes, '') = ''
				AND CANCELED <> 'N'
				AND DocEntry = @DocEntry
			)
		SELECT @ErrorCode = 50
			,@ErrorName = 'Select Cancelled Reason Field to Cancel the Document...'

	-------------------------Validate by G---------------------
	IF EXISTS (
			SELECT a.DocEntry
			FROM OINV A
			INNER JOIN EInvoice B ON A.DocEntry = B.DocEntry
			WHERE CANCELED <> 'N'
				AND A.DocEntry = @DOCENTRY
				AND b.DocType = 'INV'
			)
		SELECT @ErrorCode = 77
			,@ErrorName = ('You Cannot Cancel The IRN Generated Invoice')

	--============================================================================================= 
	 IF EXISTS (
SELECT *
FROM OINV A INNER JOIN OUSR B ON A.UserSign=B.USERID
WHERE  CANCELED <> 'N' AND USER_CODE NOT IN ('AUTO','MANAGER','SAPADMIN') and DocType<>'S'
AND DocEntry = @DocEntry
)
SELECT @ErrorCode = 012
,@ErrorName = 'Access Denied !!!!!! kindly contact Vimal (7373702147) - Accounts team '

	-----------------  Don't Delete the Bellow Lines -----------------   
	IF @ErrorCode <> 0
		UPDATE OADM
		SET U_ErrorCode = @ErrorCode
			,U_ErrorName = @ErrorName

	RETURN @ErrorCode
END
