-- ================================================
-- Template generated from Template Explorer using:
-- Create Procedure (New Menu).SQL
--
-- Use the Specify Values for Template Parameters 
-- command (Ctrl-Shift-M) to fill in the parameter 
-- values below.
--
-- This block of comments will not be included in
-- the definition of the procedure.
-- ================================================
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		praktyka
-- Create date: 
-- Description:	
-- =============================================
CREATE PROCEDURE sp_organizacje_pozarz¹dowe 
	-- Add the parameters for the stored procedure here
AS

declare @cnt int
declare @lastSourceDate date
select @cnt=count(*) --, @lastSourceDate=max([data_modyfikacji]) from [dbo].[organizacje_pozarz¹dowe]


GO
