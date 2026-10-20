#ifndef __EXT_FLASH_H
#define __EXT_FLASH_H

/*_____ I N C L U D E S ____________________________________________________*/
#include <stdint.h>
/*_____ D E F I N I T I O N S ______________________________________________*/


/*_____ M A C R O S ________________________________________________________*/

/*_____ D E C L A R A T I O N S ____________________________________________*/
uint16_t flash_read_id(void);
void flash_erase_sector(uint32_t adr);
void flash_write(uint32_t adr,uint16_t len,uint8_t *buff);
void flash_read(uint32_t adr,uint16_t len,uint8_t *buff);
#endif	/*__EXT_FLASH_H*/
