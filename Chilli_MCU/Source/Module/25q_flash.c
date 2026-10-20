/******************** (C) COPYRIGHT 2025 SONiX *******************************
* COMPANY:			SONiX
* DATE:					2025/03
* AUTHOR:				SA1
* IC:						SN32F2400
* DESCRIPTION:	25QXX SPI FLASH
*____________________________________________________________________________
* REVISION	Date				User		Description
* 1.0				2025/03/07	SA1			1. First release
*
*____________________________________________________________________________
* THE PRESENT SOFTWARE WHICH IS FOR GUIDANCE ONLY AIMS AT PROVIDING CUSTOMERS
* WITH CODING INFORMATION REGARDING THEIR PRODUCTS TIME TO MARKET.
* SONiX SHALL NOT BE HELD LIABLE FOR ANY DIRECT, INDIRECT OR CONSEQUENTIAL 
* DAMAGES WITH RESPECT TO ANY CLAIMS ARISING FROM THE CONTENT OF SUCH SOFTWARE
* AND/OR THE USE MADE BY CUSTOMERS OF THE CODING INFORMATION CONTAINED HEREIN 
* IN CONNECTION WITH THEIR PRODUCTS.
*****************************************************************************/
/*_____ I N C L U D E S ____________________________________________________*/
#include "25q_flash.h"
#include "..\Driver\SPI.h"

/*_____ D E C L A R A T I O N S ____________________________________________*/

/*_____ D E F I N I T I O N S ______________________________________________*/

#define	__IO_SEL_LOW	SN_GPIO1->BCLR = 1 << 8;
#define	__IO_SEL_HIGH	SN_GPIO1->BSET = 1 << 8;

/*_____ M A C R O S ________________________________________________________*/

/*_____ F U N C T I O N S __________________________________________________*/


/*****************************************************************************
* Function		: flash_write_enable
* Description	: 
* Input			: None
* Output		: None
* Return		: None
* Note			: None
*****************************************************************************/
void flash_write_enable(void)
{
	__IO_SEL_LOW
	SPI0_RW(0x06);
	__IO_SEL_HIGH
}
/*****************************************************************************
* Function		: SPIFlash_WaitReady
* Description	:  
* Input			: 
* Output		: 
* Return		: None
* Note			: 
*****************************************************************************/
void flash_wait_ready(void)
{
	__IO_SEL_LOW;	  
	SPI0_RW(0x05);
	while(SPI0_RW(0x00));
	__IO_SEL_HIGH;		
}
/*****************************************************************************
* Function		: flash_write_enable
* Description	: 
* Input			: None
* Output		: None
* Return		: None
* Note			: None
*****************************************************************************/
uint16_t flash_read_id(void)
{
  uint16_t id = 0;
  
	__IO_SEL_LOW
	SPI0_RW(0x9F);
	id = SPI0_RW(0);    //Manufacturer ID(EFH)
	id = SPI0_RW(0)<<8;
	id|= SPI0_RW(0);
	
	__IO_SEL_HIGH;
  
  return id;
}
/*****************************************************************************
* Function		: flash_erase_sector
* Description	: 
* Input			: None
* Output		: None
* Return		: None
* Note			: None
*****************************************************************************/
void flash_erase_sector(uint32_t adr)
{
	flash_wait_ready();
	flash_write_enable();
	__IO_SEL_LOW
	SPI0_RW(0x20);
	SPI0_RW(adr>>16);
	SPI0_RW(adr>>8);
	SPI0_RW(adr&0xFF);	
	
	__IO_SEL_HIGH;
}
/*****************************************************************************
* Function		: flash_write
* Description	: 
* Input			: None
* Output		: None
* Return		: None
* Note			: None
*****************************************************************************/
void flash_write(uint32_t adr,uint16_t len,uint8_t *buff)
{
	flash_wait_ready();
	flash_write_enable();
	
	__IO_SEL_LOW
	SPI0_RW(0x02);
	SPI0_RW(adr>>16);
	SPI0_RW(adr>>8);
	SPI0_RW(adr&0xFF);
	
	while(len--)
	{
		SPI0_RW(*buff++);
	}
	
	__IO_SEL_HIGH;
	
}
/*****************************************************************************
* Function		: flash_read
* Description	: 
* Input			: None
* Output		: None
* Return		: None
* Note			: None
*****************************************************************************/
void flash_read(uint32_t adr,uint16_t len,uint8_t *buff)
{
	uint16_t i;
	flash_wait_ready();
	__IO_SEL_LOW
	SPI0_RW(0x03);
	SPI0_RW(adr>>16);
	SPI0_RW(adr>>8);
	SPI0_RW(adr&0xFF);
	
	for(i=0;i<len;i++)
		buff[i] = SPI0_RW(0);
	__IO_SEL_HIGH
}
