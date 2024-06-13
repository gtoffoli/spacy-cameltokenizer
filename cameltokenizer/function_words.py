conjunction_list = (
    "لأن", # because
	"إنما", # but rather
)
CONJUNCTIONS = set(conjunction_list)

# adverbs", # from https://mylanguages.org/arabic_adverbs.php

adverb_list = (
# adverbs of time	"ظُرُوْف الْوَقْت", # thorowf alwaqt
	"أمس", # yesterday
	"اليوم", # today
	"غدا", # tomorrow
	"الآن", # now
	"ثم", # then
	"بعد", # later
	"الليلة", # tonight
	"سابقا", # already
	"مؤخرا", # recently
	"قريبا", # soon
	"فورا", # immediately
	"بعد", # yet
	"منذ", # ago
# adverbs of place	"ظُرُوْف مَكَان", # thorowf makaan
	"هنا", # here
	"هناك", # there
	"منزل", # home
	"بعيدا", # away
	"خارِج", # out
# adverbs of manner	"ظُرُوْف مِن الْطَّرِيْقَة", # thorowf men altareeeqah
	"جدا", # very
	"تماما", # quite
	"جميل", # pretty
	"حقا", # really
	"سريع", # fast
	"جيد", # well
	"الثابت", # hard
	# "بسرعة", # quickly
	# "ببطء", # slowly
	# "بعناية", # carefully
	"بالكاد", # hardly
	"تقريبا", # almost
	"إطلاقا", # absolutely
	"معا", # together
	# "وحدها", # alone
# adverbs of frequency	"ظُرُوْف مِن الْتَّرَدُّد", # thorowf men altaradod
	"دائما", # always
	"كثيرا", # frequently
	"عَادَة", # usually
	"أحيانا", # sometimes
	"نادرا", # rarely
	"أبدا", # never

# my additions
	"حوالي", # approximately
	"مستمراً", # continually
	# "لاسيما", # especially, 130 45, adv x part/noun
	"أخيراً", # finally
	"عالمياً", # globally
	# "لقد", # indeed, 313 113, x part/part
	"نسبياً", # relatively
)

ADVERBS = set(adverb_list)

# prepositions, # from http://www.modernstandardarabic.com/arabic-prepositions-list/

preposition_list = (
	"حول", # about, around
	"فوق", # above
	"عبر", # across
	"بعد", # after
	"بين", # among, between
	"كما", # as
	"قبل", # before
	"وراء", # behind, beyond
	"تحت", # beneath
	# "بجانب", # beside
	"لكن", # but
	"أسفل", # down
	"خلال", # during
	"إِلا", # except
	"داخل", # inside
	"قرب", # near
	"التالي", # next, toward
	"معاكس", # opposite
	"خارج", # outside
	# "لكل", # per
	"زائد", # plus
	"جولة", # round
	"منذ", # since
	"إِلى", # to
	"حتى", # until
	# "بواسطة", # via
	"ضمن", # within
	# "بدون", # without
# Two Word Prepositions
	# "بحسب", # according to
	# "بسبب", # because of
	# "باستثناء", # except for
# Three Word Prepositions
	"أمام", # in front of
	# "باسم", # on behalf of
)
PREPOSITIONS = set(preposition_list)

pronoun_list = (
    "بعض", # some
    "نا",
    "ه",
    "ها",
    "هم",
)
PRONOUNS = set(pronoun_list)

noun_list = (
	"واردات", # imports
    "مليوناً", # milione?
	"فلاح", # peasant
	"جنيها", # pounds
	"كبريات", # Sulfur
)
NOUNS = set(noun_list)
