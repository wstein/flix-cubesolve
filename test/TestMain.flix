@Test
def testGreeting(): Unit \ Assert =
    Assert.assertEq(expected = "Hello, World!", Hello.greeting("World"))

@Test
def testGreetingUsesTheGivenName(): Unit \ Assert =
    Assert.assertEq(expected = "Hello, Flix!", Hello.greeting("Flix"))

@Test
def testGreetingWithEmptyName(): Unit \ Assert =
    Assert.assertEq(expected = "Hello, !", Hello.greeting(""))
